# Theme System Tests

Additional guidance for testing themes and theme components.

## Directory Structure

```
theme/
  spec/
    system/
      filter_sidebar_spec.rb
      toggle_dark_mode_spec.rb
      page_objects/
        components/
          sidebar.rb
```

- Tests go in `spec/system`
- Files must match `*_spec.rb` pattern

## Test Structure

```rb
# frozen_string_literal: true

require_relative "page_objects/components/sidebar"

RSpec.describe "Filter sidebar", system: true do
  let!(:theme) { upload_theme }
  # For components: let!(:theme) { upload_theme_component }

  fab!(:category)

  let(:sidebar) { PageObjects::Components::Sidebar.new }

  it "filters and displays categories" do
    visit("/")

    sidebar.filter(category.name)

    expect(sidebar).to have_category(category)
  end
end
```

## Helpers

| Helper | Purpose |
|--------|---------|
| `upload_theme` | Upload the theme being tested |
| `upload_theme_component` | Upload a theme component |

## Theme Settings

```rb
it "respects settings" do
  theme.update_setting(:my_setting, false)
  theme.save!

  visit("/")
  expect(page).not_to have_css(".my-feature")
end
```

## Running Theme Tests

Clone themes into `tmp/themes` in the Discourse directory, then run from Discourse root:

```sh
# Run all theme system tests
bin/rspec tmp/themes/my-theme/spec/system

# Run specific file
bin/rspec tmp/themes/my-theme/spec/system/my_spec.rb

# Run specific line
bin/rspec tmp/themes/my-theme/spec/system/my_spec.rb:15

# Run with visible browser
SELENIUM_HEADLESS=0 bin/rspec tmp/themes/my-theme/spec/system

# If theme relies on a plugin being enabled
LOAD_PLUGINS=1 bin/rspec tmp/themes/my-theme/spec/system
```
