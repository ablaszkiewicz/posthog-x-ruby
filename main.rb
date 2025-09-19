#!/usr/bin/env ruby

# Using the local modified version of posthog-ruby with exception capture
require 'bundler/setup'
require 'posthog'
require 'logger'

# Initialize PostHog client with debug logging
posthog = PostHog::Client.new({
  api_key: 'phc_VXlGk6yOu3agIn0h7lTmSOECAGWCtJonUJDAN4CexlJ',
  host: 'http://localhost:8010',
})

# Enable debug logging
posthog.logger.level = Logger::DEBUG

puts "Testing PostHog Ruby SDK - Exception Capture"
puts "=" * 50

# Capture a simple exception
begin
  # Intentionally cause an error
  raise StandardError, "This is a test exception!"
rescue => e
  puts "\nCaught exception: #{e.class.name}: #{e.message}"
  puts "Sending to PostHog..."
  
  # Capture the exception with PostHog
  posthog.capture_exception(e, 'test-user-123')
  
  puts "Exception sent!"
end

# Flush to ensure the event is sent immediately
puts "\nFlushing..."
posthog.flush

puts "Done! Check your PostHog dashboard for the $exception event."