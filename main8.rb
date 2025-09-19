#!/usr/bin/env ruby

require 'bundler/setup'
require 'posthog'
require 'logger'
require_relative 'error_simulator'

posthog = PostHog::Client.new({
  api_key: 'phc_VXlGk6yOu3agIn0h7lTmSOECAGWCtJonUJDAN4CexlJ',
  host: 'http://localhost:8010',
})

posthog.logger.level = Logger::DEBUG

begin
  ErrorSimulator.simulate_database_error
rescue => e
  posthog.capture_exception(e, 'test-user-123')
end

posthog.flush
