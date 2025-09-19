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
      
      {
        'filename' => File.basename(file),
        'abs_path' => file,
        'lineno' => lineno,
        'function' => function,
        'in_app' => !is_gem_path?(file),
        'platform' => 'ruby'
      }
    end

    def self.is_gem_path?(path)
      path.include?('/gems/') || 
      path.include?('/ruby/') ||
      path.include?('/.rbenv/') ||
      path.include?('/.rvm/')
    end
  end
end