# frozen_string_literal: true

# This exception capture implementation is based on and adapted from
# Sentry Ruby SDK (https://github.com/getsentry/sentry-ruby)
# Licensed under the MIT License
# Copyright (c) 2020 Sentry
# 
# Key concepts adapted:
# - Backtrace line parsing with regex patterns
# - Exception cause chain handling
# - Stack frame formatting with context lines
# - In-app frame detection

require 'json'

module PostHog
  module ExceptionCapture
    # Adapted from sentry-ruby/lib/sentry/backtrace.rb lines 12-16
    # regexp (optional leading X: on windows)
    RUBY_INPUT_FORMAT = /
      ^ \s* (?: [a-zA-Z]: )? ([^:]+ | <.*>):
      (\d+)
      (?: :in\s('|`)(?:([\w:]+)\#)?([^']+)')?$
    /x

    def self.build_exception_properties(exception, additional_properties = {})
      exception_list = build_exception_list(exception)
      
      # Use only the first exception in the list for type and value
      exception_type = exception_list.first && exception_list.first['type']
      exception_value = exception_list.first && exception_list.first['value']
      
      properties = {
        '$exception_type' => exception_type,
        '$exception_value' => exception_value,
        '$exception_list' => exception_list
      }
      
      $stderr.puts "\n[PostHog::ExceptionCapture] Exception properties:"
      $stderr.puts JSON.pretty_generate(properties)

      properties.merge!(additional_properties) if additional_properties

      properties
    end

    private

    # Adapted from sentry-ruby/lib/sentry/utils/exception_cause_chain.rb lines 6-18
    def self.build_exception_list(exception)
      exceptions = []
      seen_objects = []
      
      current = exception
      while current
        # Avoid infinite loops
        break if seen_objects.any? { |e| e.object_id == current.object_id }
        
        seen_objects << current
        exceptions << build_single_exception(current, exceptions.length > 0)
        
        current = current.respond_to?(:cause) ? current.cause : nil
      end
      
      exceptions.reverse
    end

    # Adapted from sentry-ruby/lib/sentry/interfaces/single_exception.rb lines 17-33
    # and sentry-ruby/lib/sentry/interfaces/exception.rb lines 33-39
    def self.build_single_exception(exception, is_chained = false)
      exc_info = {
        'type' => exception.class.to_s,
        'value' => format_exception_value(exception),
        'module' => extract_module_name(exception.class.to_s),
        'mechanism' => {
          'type' => is_chained ? 'chained' : 'generic',
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
    
    # THIS IS GOOD
    # Adapted from sentry-ruby/lib/sentry/interfaces/single_exception.rb lines 19-27
    def self.format_exception_value(exception)
      message = if exception.respond_to?(:detailed_message)
                  exception.detailed_message(highlight: false)
                else
                  exception.message || ""
                end
      
      message = message.inspect unless message.is_a?(String)
      
      message.byteslice(0..1024)
    end
    
    # THIS IS GOOD
    # Adapted from sentry-ruby/lib/sentry/interfaces/single_exception.rb line 29
    def self.extract_module_name(class_name)
      # Extract module from class name (e.g., "MyModule::MyClass" => "MyModule")
      parts = class_name.split("::")
      parts.length > 1 ? parts[0...-1].join("::") : nil
    end

    # THIS IS GOOD
    # Adapted from sentry-ruby/lib/sentry/interfaces/stacktrace_builder.rb lines 66-76
    def self.build_stack_frames(backtrace)
      frames = backtrace.map do |line|
        parse_backtrace_line(line)
      end.compact
      
      # Reverse frames so innermost is last
      frames.reverse
    end

    # THIS IS GOOD
    # Adapted from sentry-ruby/lib/sentry/backtrace.rb lines 38-50
    # This closely follows Sentry's Line.parse method
    def self.parse_backtrace_line(unparsed_line)
      ruby_match = unparsed_line.match(RUBY_INPUT_FORMAT)
      return nil unless ruby_match
      
      # Extract match groups exactly like Sentry does
      _, file, number, _, module_name, method = ruby_match.to_a
      
      # Build the frame similar to how Sentry builds their Line object
      frame = build_frame(file, number.to_i, method, module_name)
      
      # Add context lines if possible
      if frame['abs_path'] && File.exist?(frame['abs_path'])
        add_context_lines(frame, frame['abs_path'], frame['lineno'])
      end
      
      frame
    end
    
    # THIS IS GOOD
    # Adapted from sentry-ruby/lib/sentry/interfaces/stacktrace.rb lines 30-40
    # This mirrors how Sentry's Frame initializer works
    def self.build_frame(file, lineno, method, module_name)
      abs_path = compute_abs_path(file)
      filename = compute_filename(abs_path, file)
      
      {
        'abs_path' => abs_path,
        'filename' => filename,
        'lineno' => lineno,
        'function' => method,
        'module' => module_name,
        'in_app' => determine_in_app(abs_path),
        'platform' => 'ruby'
      }
    end
    
    # Adapted from sentry-ruby/lib/sentry/interfaces/stacktrace.rb lines 34-35
    def self.compute_abs_path(file)
      return file if file.start_with?('<') && file.end_with?('>')
      return file if file == '(irb)' || file == '(pry)' || file == '(eval)'
      
      begin
        File.expand_path(file)
      rescue
        file
      end
    end
    
    # Adapted from sentry-ruby/lib/sentry/interfaces/stacktrace.rb lines 46-60
    # This follows Sentry's compute_filename logic
    def self.compute_filename(abs_path, original_file)
      return original_file unless abs_path
      
      # Try to strip load paths like Sentry does
      longest_load_path = $LOAD_PATH
        .select { |path| abs_path.start_with?(path.to_s) }
        .max_by(&:size)
      
      if longest_load_path
        # Strip the load path
        abs_path[longest_load_path.to_s.chomp(File::SEPARATOR).length + 1..-1]
      elsif abs_path.start_with?(project_root)
        # Strip project root
        abs_path[project_root.chomp(File::SEPARATOR).length + 1..-1]
      else
        original_file
      end
    end
    
    # Helper to get project root (simplified version of Sentry's approach)
    def self.project_root
      @project_root ||= begin
        if defined?(Rails) && Rails.root
          Rails.root.to_s
        else
          Dir.pwd
        end
      end
    end
    
    # Adapted from sentry-ruby/lib/sentry/backtrace.rb lines 60-68
    # and sentry-ruby/lib/sentry/interfaces/stacktrace.rb lines 80-82
    def self.determine_in_app(abs_path)
      return false unless abs_path
      
      # Check if it's under project root
      return true if abs_path.start_with?(project_root)
      
      # Not in app if it's in a gem or Ruby internals
      return false if abs_path =~ %r{(/gems/|/ruby/|/rubies/|/.rbenv/|/.rvm/|/vendor/bundle/)}
      
      # Special non-app sources
      return false if abs_path.start_with?('<') && abs_path.end_with?('>')
      return false if abs_path == '(irb)' || abs_path == '(pry)' || abs_path == '(eval)'
      
      false
    end
    
    # Adapted from sentry-ruby/lib/sentry/linecache.rb lines 14-20
    # This closely follows Sentry's LineCache.get_file_context
    def self.add_context_lines(frame, file_path, lineno, context_size = 5)
      begin
        return unless File.exist?(file_path)
        
        lines = File.readlines(file_path)
        return if lines.empty? || lineno < 1 || lineno > lines.length
        
        # Get ranges exactly like Sentry does
        pre_context_start = [lineno - context_size, 1].max
        pre_context_end = [lineno - 1, 0].max
        post_context_start = lineno
        post_context_end = [lineno + context_size - 1, lines.length - 1].min
        
        # Set context exactly like Sentry does
        frame['context_line'] = lines[lineno - 1]&.chomp
        
        if pre_context_end >= pre_context_start
          frame['pre_context'] = lines[(pre_context_start - 1)...(lineno - 1)].map(&:chomp)
        end
        
        if post_context_end >= post_context_start
          frame['post_context'] = lines[lineno..(post_context_end)].map(&:chomp)
        end
      rescue => e
        # Silently ignore like Sentry does
      end
    end
  end
end