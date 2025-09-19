# PostHog x Ruby Demo

A Ruby application demonstrating PostHog analytics integration including event tracking, user properties, feature flags, and A/B testing.

## Features

This demo application showcases:

- **PostHog Integration**: Complete analytics setup with the `posthog-ruby` SDK
- **Event Tracking**: Custom event capturing with properties
- **User Properties**: Setting and updating user profiles
- **Feature Flags**: Conditional feature rollouts and targeting
- **A/B Testing**: Experiments with multiple variants
- **Error Handling**: Robust error handling for analytics calls
- **Ruby Best Practices**: Clean code structure and patterns

### PostHog Features Demonstrated

- ✅ Event capture with custom properties
- ✅ User identification and properties ($set, $set_once)
- ✅ Feature flag evaluation (`is_feature_enabled`)
- ✅ Multivariate feature flags (`get_feature_flag`)
- ✅ A/B testing and experiments
- ✅ Error handling and fallbacks

## Prerequisites

- Ruby 3.0+ installed on your system
- Bundler gem (install with `gem install bundler`)
- PostHog account (sign up free at [posthog.com](https://posthog.com))

## Setup

1. Clone or download this repository
2. Navigate to the project directory:

   ```bash
   cd posthog-x-ruby
   ```

3. Install dependencies:

   ```bash
   bundle install
   ```

4. **PostHog Configuration**:
   - Create a `.env` file in the project root
   - Copy the contents from `.env.example` (if available) or add:
     ```bash
     POSTHOG_API_KEY=phc_your_project_api_key_here
     POSTHOG_HOST=https://us.i.posthog.com
     ```
   - Get your API key from [PostHog Project Settings](https://app.posthog.com/project/settings)
   - Replace `phc_your_project_api_key_here` with your actual API key

> **Note**: The app will run without PostHog credentials but will show connection errors. For full functionality, configure your PostHog project.

## How to Run

### Option 1: Run directly with Ruby

```bash
ruby main.rb
```

### Option 2: Run with Bundle (recommended)

```bash
bundle exec ruby main.rb
```

### Option 3: Make it executable

```bash
chmod +x main.rb
./main.rb
```

## What You'll See

When you run the application, it will:

1. **Initialize PostHog** with your API key and generate a unique user ID
2. **Track Events** for each demo section (variables, arrays, hashes, methods)
3. **Set User Properties** including name, language preference, and demo version
4. **Test Feature Flags** by checking multiple flag configurations
5. **Run A/B Tests** by assigning the user to an experiment variant
6. **Simulate User Behavior** like clicking buttons based on experiment groups

### Sample Output:

```
🔗 PostHog initialized for user: 123e4567-e89b-12d3-a456-426614174000
==================================================
Welcome to PostHog x Ruby Demo!
Version: 1.0.0
==================================================

📈 Tracked event: application_started
👤 Set user properties for ID: 123e4567-e89b-12d3-a456-426614174000

📦 Variables Demo:
  Language: Ruby
  Age: 30 years
  Is awesome: true
📈 Tracked event: demo_section_viewed

🚩 PostHog Feature Flags Demo:
  new-ui-design: ❌ DISABLED
  beta-features: ✅ ENABLED
    → Using new UI components!
  advanced-analytics: ❌ DISABLED
📈 Tracked event: feature_flag_checked

🧪 PostHog A/B Testing Demo:
  User is in VARIANT A: Large green CTA button
  🖱️  User clicked the green 'Start Free Trial' button!
📈 Tracked event: experiment_viewed
📈 Tracked event: cta_clicked

Check your PostHog dashboard to see the tracked events! 📊
```

## Development

### Running Tests (once you add them)

```bash
bundle exec rspec
```

### Code Linting

```bash
bundle exec rubocop
```

### Interactive Debugging

Use the `pry` gem that's included in the development dependencies:

```ruby
require 'pry'
binding.pry  # Add this line anywhere in your code
```

## Project Structure

```
posthog-x-ruby/
├── main.rb              # Main application with PostHog integration
├── Gemfile              # Dependencies including posthog-ruby
├── Gemfile.lock         # Locked dependency versions (auto-generated)
├── .env.example         # Environment variables template
├── .env                 # Your PostHog credentials (create this)
└── README.md            # This documentation
```

## Adding Dependencies

To add new gems to your project:

1. Add the gem to your `Gemfile`
2. Run `bundle install`
3. Require the gem in your Ruby files

Example:

```ruby
# In Gemfile
gem 'httparty', '~> 0.21'

# In your Ruby code
require 'httparty'
```

## PostHog Dashboard

After running the application, check your PostHog dashboard to see:

- **Events**: `application_started`, `demo_section_viewed`, `feature_flag_checked`, `experiment_viewed`, `cta_clicked`
- **User Properties**: Name, language preference, demo version, first seen timestamp
- **Feature Flags**: Usage analytics and evaluation results
- **Experiments**: A/B test results and conversion tracking

## Next Steps

### Extend PostHog Integration:

- Add **Group Analytics** for organization-level tracking
- Implement **Cohorts** for user segmentation
- Set up **Session Recording** for user behavior analysis
- Create **Custom Dashboards** and insights
- Add **Person Profiles** with custom properties

### Expand the Ruby Application:

- Add unit tests with RSpec to test PostHog integration
- Build a web interface with Sinatra or Rails
- Integrate with databases using ActiveRecord
- Add more complex feature flag logic
- Implement advanced experiment tracking

## Resources

- [PostHog Ruby SDK Documentation](https://posthog.com/docs/libraries/ruby)
- [PostHog Feature Flags Guide](https://posthog.com/docs/feature-flags)
- [PostHog Experiments (A/B Testing)](https://posthog.com/docs/experiments)
- [PostHog Dashboard](https://app.posthog.com)
