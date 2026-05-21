# System Tests

Discourse uses Rails system tests with RSpec and Capybara. Tests run both server and client code together.

## Assert What Users See, Not Database State

System tests simulate real user interactions. **Assert on visible UI state, not database records.** If a user can't see it on the page, don't check it in the database.

```rb
# Good - asserts what the user sees
expect(topic_page).to have_post(text: "Hello world")
expect(toasts).to have_success("Topic created")

# Bad - checks database state the user can't see
expect(Topic.last.title).to eq("Hello world")
expect(Post.count).to eq(1)
```

Only reach into the database when no UI signal exists for the behavior being tested, which should be rare. If you find yourself needing database assertions, consider whether the feature is missing user-visible feedback.

**Verify persistence by refreshing the page.** After a save action, refresh (or revisit) the current page and assert the saved state is still visible. This is what a real user would do to confirm their changes persisted.

```rb
# Good - refreshes and verifies saved state
admin_settings_page.save
expect(toasts).to have_success("Settings saved")

page.refresh

expect(admin_settings_page).to have_setting_value("site_name", "My Forum")

# Bad - only checks before refresh, or checks the database
admin_settings_page.save
expect(SiteSetting.site_name).to eq("My Forum")
```

## File Naming

Use `action_scenario_spec.rb` pattern - describe what the test does:
- `filter_sidebar_spec.rb` → `RSpec.describe "Filter sidebar"`
- `toggle_dark_mode_spec.rb` → `RSpec.describe "Toggle dark mode"`
- `create_topic_with_template_spec.rb` → `RSpec.describe "Create topic with template"`

Avoid generic names like `feature_spec.rb` or `my_feature_spec.rb`.

## Test Structure

```rb
# frozen_string_literal: true

RSpec.describe "Filter sidebar" do
  fab!(:user)
  fab!(:category)

  let(:sidebar) { PageObjects::Components::Sidebar.new }

  context "when logged in" do
    before { sign_in(user) }

    it "filters and displays categories" do
      visit("/")

      sidebar.filter(category.name)

      expect(sidebar).to have_category(category)
      expect(sidebar).to have_no_category("Unrelated")
    end
  end
end
```

**Key patterns:**
- Instantiate page objects with `let`
- Use `context` blocks to group related scenarios
- Batch related assertions in a single `it` block
- Never use raw selectors in test files - delegate to page objects

## Writing `it` Block Descriptions

Describe the **user interaction and expected experience**, not implementation details. System tests verify what users see and do, so descriptions should read like user stories.

```rb
# Good - describes user experience
it "allows a user to filter categories in the sidebar"
it "displays an error when submitting an empty title"
it "navigates to the topic after clicking a search result"

# Bad - describes implementation details
it "preserves the tag filter in the URL when switching categories"
it "updates the model count after deletion"
it "sets the correct query param on filter change"
```

## Freezing Time

For time-sensitive system tests, use the `time:` metadata key instead of calling `freeze_time` manually. This freezes **both** the Ruby server time and the Playwright browser clock simultaneously:

```rb
it "shows the post timestamp correctly", time: Time.zone.parse("2024-01-15 10:00:00") do
  visit(topic_path(topic))
  expect(post_component).to have_timestamp("Jan 15")
end
```

**Why this matters:** In system tests, JavaScript also needs to see the frozen time (e.g. for relative timestamps like "5 minutes ago"). The `time:` metadata calls both `freeze_time` and `pw_page.clock.set_fixed_time` under the hood. Using plain `freeze_time` only freezes the Ruby side, leaving the browser clock running normally.

## Common Helpers

| Helper | Purpose |
|--------|---------|
| `sign_in(user)` | Sign in as a user |
| `visit(path)` | Navigate to a page |
| `puts` | Debug server-side code (Ruby) |
| `console.log` | Debug client-side code (JavaScript) |
| `pause_test` | Pause to view visual state (use with `SELENIUM_HEADLESS=0`) |

## Page Objects

**Always use page objects** - never write raw selectors or Capybara finders directly in test files. Encapsulate all selectors and interactions in page object classes. Only add methods that are actually used by your tests - don't add methods speculatively.

**Prefer passing entire objects** to page object methods instead of just attributes. Let the page object extract what it needs:

```rb
# Good - page object receives the full object
def has_tag?(tag)
  has_css?("#{SELECTOR} .discourse-tag", text: tag.name)
end

# In test
expect(component).to have_tag(tag)
```

```rb
# Avoid - caller extracts the attribute
def has_tag?(name)
  has_css?("#{SELECTOR} .discourse-tag", text: name)
end

# In test
expect(component).to have_tag(tag.name)
```

**Combine related assertions** into single page object methods when checking multiple aspects of the same element:

```rb
# Good - checks both content and link in one assertion
def has_category_link?(category)
  has_css?("a.category-link[href='/c/#{category.slug}']", text: category.name)
end

# In test - single assertion covers both aspects
expect(sidebar).to have_category_link(category)
```

```rb
# Avoid - separate methods when they could be combined
def has_category_name?(category)
  has_css?(".category-name", text: category.name)
end

def has_category_link?(category)
  has_css?("a[href='/c/#{category.slug}']")
end

# In test - multiple assertions for one element
expect(sidebar).to have_category_name(category)
expect(sidebar).to have_category_link(category)
```

## Composing Page Objects

**Don't stuff everything into a single page object.** Identify UI boundaries (header, sidebar, composer, post, modal, etc.) and split them into separate component page objects. The main page object exposes methods that return instances of those components.

```rb
# Good - main page composes scoped components
module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def header
        PageObjects::Components::TopicHeader.new
      end

      def composer
        PageObjects::Components::Composer.new
      end

      def post_by_number(number)
        PageObjects::Components::Post.new(".topic-post[data-post-number='#{number}']")
      end
    end
  end
end

# In test
topic_page.visit_topic(topic)
topic_page.header.click_reply
topic_page.composer.fill_in_body("Hello")
expect(topic_page.post_by_number(2)).to be_liked
```

```rb
# Avoid - one mega page object with every selector and interaction
class Topic < PageObjects::Pages::Base
  def click_header_reply; end
  def fill_composer_body(text); end
  def post_2_liked?; end
  # ...dozens more methods spanning unrelated UI regions
end
```

Component page objects keep selectors local to the region they describe, make tests read like the UI is structured, and let components be reused across pages (e.g. the composer appears in multiple pages).

## Scoping Components to Elements

When a component appears multiple times on a page (e.g., a like button on each post), **always scope components to their parent element.**

**Bad - ambiguous component:**
```rb
let(:like_button) { PageObjects::Components::LikeButton.new }

it "likes a reply" do
  topic_page.visit_topic(topic)
  like_button.click  # Which post's like button?
  expect(like_button).to be_liked  # Ambiguous
end
```

**Good - component scoped through parent:**
```rb
let(:topic_page) { PageObjects::Pages::Topic.new }

it "likes a reply" do
  topic_page.visit_topic(topic)
  topic_page.post_by_number(2).click_like
  expect(topic_page.post_by_number(2)).to be_liked
end
```

**Two valid patterns for scoping:**

1. **Access through parent page object** (preferred) - The parent provides a method that returns a scoped component:
   ```rb
   # In page object
   def post_by_number(number)
     PageObjects::Components::Post.new(".topic-post[data-post-number='#{number}']")
   end

   # In test
   topic_page.post_by_number(2).click_like
   ```

2. **Pass scoping element to constructor** - Instantiate with a selector that scopes to the specific instance:
   ```rb
   let(:second_post) { PageObjects::Components::Post.new(".topic-post[data-post-number='2']") }

   it "likes the second post" do
     second_post.click_like
     expect(second_post).to be_liked
   end
   ```

The first pattern is preferred because it keeps selectors out of test files and makes the relationship explicit.

## S3 Upload System Tests

System specs involving S3 uploads use MinIO (a local S3-compatible server). The test infrastructure automatically downloads and runs MinIO with an isolated data store during specs.

**Writing S3 system specs:** Call `setup_or_skip_s3_system_test` as the very first line in each `it` block. This configures the S3 environment and skips the test if S3 specs aren't enabled:

```rb
it "uploads a file to S3" do
  setup_or_skip_s3_system_test

  # your test code here
end
```

**Running S3 system specs:** S3-related specs are skipped by default. Enable them with the `RUN_S3_SYSTEM_SPECS` environment variable:

```sh
RUN_S3_SYSTEM_SPECS=1 bin/rspec spec/system/s3_uploads_spec.rb
```

**Local setup required:** MinIO must be reachable at specific hostnames. Add entries to `/etc/hosts`:

```sh
# Linux
echo "127.0.0.1 minio.local discoursetest.minio.local" | sudo tee -a /etc/hosts

# macOS — also needs IPv6 entries
echo "127.0.0.1 minio.local discoursetest.minio.local" | sudo tee -a /etc/hosts
echo "::1 minio.local discoursetest.minio.local" | sudo tee -a /etc/hosts
echo "fe80::1%lo0 minio.local discoursetest.minio.local" | sudo tee -a /etc/hosts
```

To use a custom MinIO hostname, set `MINIO_RUNNER_MINIO_DOMAIN`.
