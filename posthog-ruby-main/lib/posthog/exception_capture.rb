# frozen_string_literal: true

# This exception capture implementation is based on and adapted from
# Sentry Ruby SDK (https://github.com/getsentry/sentry-ruby)
# Licensed under the MIT License
# Copyright (c) 2020 Sentry
# 
# Simplified version focusing on core functionality

require 'json'

module PostHog
  module ExceptionCapture
    RUBY_INPUT_FORMAT = /
        ^ \s* (?: [a-zA-Z]: | uri:classloader: )? ([^:]+ | <.*>):
        (\d+)
        (?: :in\s('|`)(?:([\w:]+)\#)?([^']+)')?$
      /x

    def self.build_exception_properties(exception, additional_properties = {})
      exception_info = build_single_exception(exception)
      
      properties = {
        '$exception_type' => exception_info['type'],
        '$exception_value' => exception_info['value'],
        '$exception_list' => [exception_info]  # Always single exception, no chain
      }
      
      $stderr.puts "\n[PostHog::ExceptionCapture] Exception properties:"
      $stderr.puts JSON.pretty_generate(properties)

      properties.merge!(additional_properties) if additional_properties

      properties
    end

    private

    def self.build_single_exception(exception)
      {
        'type' => exception.class.to_s,
        'value' => exception.message || "",
        'mechanism' => {
          'type' => 'generic',
          'handled' => true
        },
        'stacktrace' => build_stacktrace(exception.backtrace)
      }
    end

    def self.build_stacktrace(backtrace)
      return nil unless backtrace && !backtrace.empty?
      
      frames = backtrace.first(50).map do |line|
        parse_backtrace_line(line)
      end.compact.reverse
      
      {
        'type' => 'raw',
        'frames' => frames
      }
    end

    def self.parse_backtrace_line(line)
      match = line.match(RUBY_INPUT_FORMAT)
      return nil unless match
      
      # Extract parts from regex match (following Sentry's pattern)
      # match[0] = full match, [1] = file, [2] = line, [3] = quote char, [4] = module/class, [5] = method
      file = match[1]
      lineno = match[2].to_i
      module_name = match[4]  # Optional module/class name
      method_name = match[5]  # Actual method name
      
      # Clean up method name and handle nil case
      if method_name
        method_name = method_name.gsub(/[`']/, '')  # Remove quotes/backticks
        # Combine module and method if module exists
        function = module_name ? "#{module_name}##{method_name}" : method_name
      else
        function = '<unknown>'
      end
      
      frame = {
        'filename' => File.basename(file),
        'abs_path' => file,
        'lineno' => lineno,
        'function' => function,
        'in_app' => !is_gem_path?(file),
        'platform' => 'ruby'
      }
      
      # Add context lines if the file exists and is readable
      add_context_lines(frame, file, lineno) if File.exist?(file)
      
      frame
    end

    def self.is_gem_path?(path)
      path.include?('/gems/') || 
      path.include?('/ruby/') ||
      path.include?('/.rbenv/') ||
      path.include?('/.rvm/')
    end
    
    # Adapted from sentry-ruby/lib/sentry/linecache.rb lines 14-20
    # Adds source code context lines around the error line
    def self.add_context_lines(frame, file_path, lineno, context_size = 5)
      begin
        lines = File.readlines(file_path)
        return if lines.empty?
        
        # Make sure line number is valid
        return unless lineno > 0 && lineno <= lines.length
        
        # Calculate line ranges for context
        pre_context_start = [lineno - context_size, 1].max
        post_context_end = [lineno + context_size, lines.length].min
        
        # Get the actual error line (convert from 1-indexed to 0-indexed)
        frame['context_line'] = lines[lineno - 1].chomp
        
        # Get pre-context lines (lines before the error)
        if pre_context_start < lineno
          frame['pre_context'] = lines[(pre_context_start - 1)...(lineno - 1)].map(&:chomp)
        end
        
        # Get post-context lines (lines after the error)
        if post_context_end > lineno
          frame['post_context'] = lines[lineno...(post_context_end)].map(&:chomp)
        end
      rescue => e
        # Silently ignore file read errors
        # This can happen with eval'd code, temporary files, etc.
      end
    end
  end
end