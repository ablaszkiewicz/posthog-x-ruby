# frozen_string_literal: true

require 'json'

module PostHog
  module ExceptionCapture
    def self.build_exception_properties(exception, additional_properties = {})
      exception_list = build_exception_list(exception)
      
      # todo: should it be array?
      exception_types = exception_list.map { |exc| exc['type'] }
      exception_values = exception_list.map { |exc| exc['value'] }
      
      properties = {
        '$exception_types' => exception_types,
        '$exception_values' => exception_values,
        '$exception_list' => exception_list
      }
      
      $stderr.puts "\n[PostHog::ExceptionCapture] Exception properties:"
      $stderr.puts JSON.pretty_generate(properties)

      properties.merge!(additional_properties) if additional_properties

      properties
    end

    private

    def self.build_exception_list(exception)
      exceptions = []
      
      exceptions << build_single_exception(exception)
      
      # todo: if there's a cause (Ruby 2.1+), add it to the chain
      exceptions
    end

    def self.build_single_exception(exception)
      exc_info = {
        'type' => exception.class.name,
        'value' => exception.message,
        'mechanism' => {
          # todo: if there is cause, use 'chained'
          'type' => 'generic',
          'handled' => true
        }
      }
      
      if exception.backtrace && !exception.backtrace.empty?
        exc_info['stacktrace'] = {
          'type' => 'raw',
          'frames' => build_stack_frames(exception.backtrace)
        }
      end
      
      exc_info
    end

    def self.build_stack_frames(backtrace)
      frames = backtrace.first(100).map do |line|
        parse_backtrace_line(line)
      end.compact
      
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
      
      frame['in_app'] = !is_library_frame?(frame['abs_path'] || frame['filename'])
      
      if frame['abs_path'] && File.exist?(frame['abs_path'])
        add_context_lines(frame, frame['abs_path'], frame['lineno'])
      end
      
      frame
    end
    
    def self.clean_function_name(function_name)
      function_name
        .gsub(/^block\s*(\(\d+ levels?\))?\s*in\s*/, '')
        .gsub(/[`']/, '')
    end
    
    def self.get_relative_path(path)
      if path.start_with?(Dir.pwd)
        path.sub(Dir.pwd + '/', '')
      else
        File.basename(path)
      end
    end

    def self.is_library_frame?(path)
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
        
        start_line = [lineno - 5, 1].max
        end_line = [lineno + 5, lines.length].min
        
        if lineno > 0 && lineno <= lines.length
          frame['context_line'] = lines[lineno - 1].chomp if lines[lineno - 1]
          
          if start_line < lineno
            frame['pre_context'] = lines[(start_line - 1)...(lineno - 1)].map(&:chomp)
          end
          
          if end_line > lineno
            frame['post_context'] = lines[lineno...(end_line)].map(&:chomp)
          end
        end
      rescue => e
        # todo: we can't read the file. Do something with it.
      end
    end
  end
end