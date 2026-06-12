[![Gem Version](https://badge.fury.io/rb/capybara-playwright-driver.svg)](https://badge.fury.io/rb/capybara-playwright-driver)

# 🎭 Playwright driver for Capybara

Make it easy to introduce Playwright into your Rails application.

```ruby
gem 'capybara-playwright-driver'
```

**NOTE**: If you want to use Playwright-native features (such as auto-waiting, various type of locators, ...), [consider using playwright-ruby-client directly](https://playwright-ruby-client.vercel.app/docs/article/guides/rails_integration_with_null_driver).

## Examples

```ruby
require 'capybara-playwright-driver'

# setup
Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(app, browser_type: :firefox, headless: false)
end
Capybara.default_max_wait_time = 15
Capybara.default_driver = :playwright
Capybara.save_path = 'tmp/capybara'

# run
Capybara.app_host = 'https://github.com'
visit '/'
first('div.search-input-container').click
fill_in('query-builder-test', with: 'Capybara')

## [REMARK] We can use Playwright-native selector and action, instead of Capybara DSL.
# first('[aria-label="Capybara, Search all of GitHub"]').click
page.driver.with_playwright_page do |page|
  page.get_by_label('Capybara, Search all of GitHub').click
end

all('[data-testid="results-list"] h3').each do |li|
  #puts "#{li.all('a').first.text} by Capybara"
  puts "#{li.with_playwright_element_handle { |handle| handle.text_content }} by Playwright"
end
```

Refer the [documentation](https://playwright-ruby-client.vercel.app/docs/article/guides/rails_integration) for more detailed configuration.

## Development

Prepare to run tests:

```bash
bundle install
export PLAYWRIGHT_CLI_VERSION=$(bundle exec ruby -e 'require "playwright"; puts Playwright::COMPATIBLE_PLAYWRIGHT_VERSION.strip')
npm install playwright@${PLAYWRIGHT_CLI_VERSION}
./node_modules/.bin/playwright install --with-deps
```

Now, run tests: note that they are run in a virtual framebuffer (Xvfb).

```bash
PLAYWRIGHT_CLI_EXECUTABLE_PATH=./node_modules/.bin/playwright xvfb-run bundle exec rspec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capybara::Playwright project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/YusukeIwaki/capybara-playwright-driver/blob/main/CODE_OF_CONDUCT.md).
