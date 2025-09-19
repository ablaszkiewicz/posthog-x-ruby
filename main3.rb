#!/usr/bin/env ruby

require 'bundler/setup'
require 'posthog'
require 'logger'

posthog = PostHog::Client.new({
  api_key: 'phc_VXlGk6yOu3agIn0h7lTmSOECAGWCtJonUJDAN4CexlJ',
  host: 'http://localhost:8010',
})

posthog.logger.level = Logger::DEBUG


begin
  raise StandardError, "This is a test2 exception!"
rescue => e
  posthog.capture_exception(e, 'test-user-123')
end

posthog.flush

