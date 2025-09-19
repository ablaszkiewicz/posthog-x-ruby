#!/usr/bin/env ruby

require 'posthog'
require 'logger'

# Initialize PostHog client with debug logging
posthog = PostHog::Client.new({
  api_key: 'phc_VXlGk6yOu3agIn0h7lTmSOECAGWCtJonUJDAN4CexlJ',
  host: 'http://localhost:8010',
})

# Enable debug logging
posthog.logger.level = Logger::DEBUG


# Send a simple event with error handling
begin
  posthog.capture({
    distinct_id: 'user-123',
    event: 'button_clicked',
    properties: {
      button_name: 'signup',
      timestamp: Time.now.iso8601
    }
  })
  
  
  # Force flush to ensure event is sent immediately
  posthog.flush
  
rescue => e
  puts "Error sending event: #{e.message}"
  puts "Error backtrace: #{e.backtrace.first(5).join("\n")}"
end
