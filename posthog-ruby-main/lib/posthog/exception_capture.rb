# frozen_string_literal: true

require 'json'

module PostHog
  module ExceptionCapture
    # Builds exception properties in a format compatible with PostHog's exception tracking
    # Based on the Python SDK implementation for consistency
    def self.build_exception_properties(exception, additional_properties = {})
      # Get the exception details
      exception_list = build_exception_list(exception)
      
      # Build the main properties following Python SDK format
      properties = {
        '$exception_type' => exception.class.name,
        '$exception_message' => exception.message,
        '$exception_list' => exception_list
      }
      
      $stderr.puts "\n[PostHog::ExceptionCapture] Exception properties:"
      $stderr.puts JSON.pretty_generate(properties)

      # Merge any additional properties
      properties.merge!(additional_properties) if additional_properties

      properties
    end

    private

    def self.build_exception_list(exception)
      # Build a list of exceptions (in Ruby we typically have just one)
      # but we format it as a list to match the Python SDK
      exceptions = []
      
      # Process the main exception
      exceptions << build_single_exception(exception)
      
      # If there's a cause (Ruby 2.1+), add it to the chain
      if exception.respond_to?(:cause) && exception.cause
        current = exception.cause
        while current
          exceptions << build_single_exception(current, true)
          current = current.respond_to?(:cause) ? current.cause : nil
        end
      end
      
      # Reverse the list so the root cause is first (matching Python SDK behavior)
      exceptions.reverse
    end

    def self.build_single_exception(exception, is_cause = false)
      exc_info = {
        'type' => exception.class.name,
        'value' => exception.message,
        'module' => get_module_name(exception),
        'mechanism' => {
          'type' => is_cause ? 'chained' : 'generic',
          'handled' => true
        }
      }
      
      # Add stack trace if available
      if exception.backtrace && !exception.backtrace.empty?
        exc_info['stacktrace'] = {
          'frames' => build_stack_frames(exception.backtrace)
        }
      end
      
      exc_info
    end
    
    def self.get_module_name(exception)
      # Try to get the module name from the exception class
      class_name = exception.class.name
      parts = class_name.split('::')
      
      if parts.length > 1
        # Return the module part (everything except the last part)
        parts[0...-1].join('::')
      else
        nil
      end
    end

    def self.build_stack_frames(backtrace)
      # Take first 100 frames to avoid massive payloads
      frames = backtrace.first(100).map do |line|
        parse_backtrace_line(line)
      end.compact
      
      # Python SDK returns frames in reverse order (innermost last)
      frames.reverse
    end

    def self.parse_backtrace_line(line)
      # Ruby backtrace format: file:line:in `method'
      # or: file:line
      # or: file:line:in block in method
      # or: file:line:in block (2 levels) in method
      
      frame = {}
      
      if match = line.match(/^(.+?):(\d+):in [`'](.+?)'?$/)
        frame = {
          'filename' => get_relative_path(match[1]),
          'abs_path' => (File.expand_path(match[1]) rescue match[1]),
          'lineno' => match[2].to_i,
          'function' => clean_function_name(match[3]),
          'platform' => 'ruby'
        }
      elsif match = line.match(/^(.+?):(\d+)$/)
        frame = {
          'filename' => get_relative_path(match[1]),
          'abs_path' => (File.expand_path(match[1]) rescue match[1]),
          'lineno' => match[2].to_i,
          'function' => '<unknown>',
          'platform' => 'ruby'
        }
      else
        return nil
      end
      
      # Add in_app flag
      frame['in_app'] = !is_library_frame?(frame['abs_path'] || frame['filename'])
      
      # Try to add context lines if possible
      if frame['abs_path'] && File.exist?(frame['abs_path'])
        add_context_lines(frame, frame['abs_path'], frame['lineno'])
      end
      
      frame
    end
    
    def self.clean_function_name(function_name)
      # Clean up function names like "block in method" or "block (2 levels) in method"
      function_name
        .gsub(/^block\s*(\(\d+ levels?\))?\s*in\s*/, '')
        .gsub(/[`']/, '')
    end
    
    def self.get_relative_path(path)
      # Try to make path relative to current working directory
      if path.start_with?(Dir.pwd)
        path.sub(Dir.pwd + '/', '')
      else
        File.basename(path)
      end
    end

    def self.is_library_frame?(path)
      # Mark frames as library frames if they're from gems or ruby internals
      path.include?('/gems/') ||
        path.include?('/rubies/') ||
        path.include?('/ruby/') ||
        path.include?('/.rbenv/') ||
        path.include?('/.rvm/') ||
        path.include?('/vendor/bundle/') ||
        path.start_with?('<internal:') ||
        path == '(irb)' ||
        path == '(pry)' ||
        path == '(eval)'
    end
    
    def self.add_context_lines(frame, file_path, lineno)
      begin
        lines = File.readlines(file_path)
        
        # Get context lines (5 before and after, like Python SDK)
        start_line = [lineno - 5, 1].max
        end_line = [lineno + 5, lines.length].min
        
        if lineno > 0 && lineno <= lines.length
          # Arrays are 0-indexed, line numbers are 1-indexed
          frame['context_line'] = lines[lineno - 1].chomp if lines[lineno - 1]
          
          # Pre-context (lines before)
          if start_line < lineno
            frame['pre_context'] = lines[(start_line - 1)...(lineno - 1)].map(&:chomp)
          end
          
          # Post-context (lines after)
          if end_line > lineno
            frame['post_context'] = lines[lineno...(end_line)].map(&:chomp)
          end
        end
      rescue => e
        # Silently ignore if we can't read the file
      end
    end
  end
end