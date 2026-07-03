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

## Don't Assert on Transient States

**Do not assert on transient UI states in system tests** — loading spinners, in-flight error banners, optimistic UI mid-flip, skeleton placeholders, or any state that resolves on its own as the page settles. By the time Capybara polls for the assertion, the state has usually already changed, producing flaky tests. Even when they pass, they exercise timing-dependent code paths that drift with unrelated network and perf shifts.

Route transient-state verification to the layer that lets you pin the state without racing the runner:

- **qunit component tests** — state can be stubbed or held in a known value while the assertion runs. This is the right home for `{{#if loading}}` / `{{#if error}}` guards and other mid-flight branches.
- **Code review** — for simple structural guards (e.g., a button that's only rendered when a chart has loaded), reading the template is more reliable than racing a test against the transition.

System tests own the **stable outcomes**: the final rendered state after the flow completes, persisted changes the user can see, navigation results. Mid-flight is qunit's job.

## URL Assertions

**Use exact-string matches with `have_current_path`.** Do not pass a regex unless the URL genuinely contains a value you cannot predict (a UUID, an auto-generated slug, a server-assigned id).

```rb
# Good - exact match: catches extra params, wrong separators, encoding bugs
expect(page).to have_current_path(
  "/admin/reports/site_traffic?end_date=2026-05-31&start_date=2026-05-01"
)

# Bad - regex tolerates extra params, wrong path prefixes, and encoding bugs
expect(page).to have_current_path(
  %r{\A/admin/reports/site_traffic\?.*start_date=2026-05-01}
)
```

Regex assertions look like a clean fix for query-param ordering surprises, but they trade away the test's strongest property — it stops asserting **the exact URL the user sees**. A regex passes when extra params get silently appended, when the path prefix drifts, when the separator is wrong, when encoding breaks. An exact match catches all of those.

**When the framework produces a URL ordering that surprises you, update the expected string — don't soften the matcher.** Ember sorts query params alphabetically on navigation, so a link declared as `?start_date=…&end_date=…` lands on `?end_date=…&start_date=…`. The correct response is to spell the expected URL in the order the framework actually produces. If the ordering is non-obvious, add a one-line comment explaining why — but keep the assertion exact.

Reach for regex only when the URL genuinely contains a value you can't predict at write time (UUID, generated token). Even then, anchor the regex (`\A...\z`) and pin everything except the unpredictable segment, so the matcher still catches the failures it would have caught with an exact string.

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

System tests exercise the product from the user's seat. Descriptions should read as **what the user does, sees, or experiences when interacting with the system** — never as what the system internally does in response.

A good check: if you removed the `it`, the description should still sound like a sentence a user (or a PM writing acceptance criteria) would say. Phrases like "displays...", "updates...", "sets...", "renders...", "calls...", "persists..." are the system's voice — rewrite them from the user's side.

```rb
# Good - user-perspective: what the user does or sees
it "lets the user filter categories in the sidebar"
it "shows the user an error when they submit an empty title"
it "takes the user to the topic after they click a search result"
it "keeps the user's tag filter visible after they switch categories"

# Bad - system-perspective: what the system does internally
it "displays an error when title is blank"
it "navigates to the topic on search result click"
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

## Debugging Failed System Tests

**When a system test fails, diagnose before fixing.** Guessing at fixes without understanding the failure burns retries and lands the wrong patch.

If you changed frontend code (`.js` / `.hbs` / `.gjs` / `.gts`) and the behavior suggests your changes aren't being picked up, the asset build is stale. Run `pnpm build` to rebuild, then re-run the test. This is only needed when `bin/dev` isn't already running in the background.

For runtime visibility, add `puts "DEBUG: …"` in Ruby (controllers, models, services, jobs) or `console.log("DEBUG: …")` in JavaScript (components, services, routes). Place logs at the entry point of the code path, around conditional branches, and at the line where the failure occurs. Re-run with documentation format so the output reads cleanly:

```sh
bin/rspec spec/system/some_spec.rb:LINE --format documentation
```

Read the debug output and ask: what values are actually present versus expected? Is the code path reached at all? Is there a timing issue? Is the test data set up correctly? Once you understand the root cause, make a targeted fix and **remove every `DEBUG:` log line** before finalizing.

Common failure patterns:

| Symptom | Likely cause | Debug approach |
|---|---|---|
| Element not found | Selector wrong, element not rendered, timing | `console.log` in the component, double-check the selector in the test |
| Unexpected content | Wrong data, rendering issue | `puts` in the controller/serializer to check data flow |
| JS changes not reflected | Assets not rebuilt | Run `pnpm build` |
| Flaky pass/fail | Timing issue | Add waits, check for async operations |
| 404/500 in test | Route or controller issue | `puts` in the route handler, check server logs |

## Test Selectors in Templates

Discourse's Ember app ships [`ember-test-selectors`](https://github.com/mainmatter/ember-test-selectors), which **strips every `data-test-*` attribute from production builds** at compile time. They're free to add in `.gjs` / `.hbs` templates: tests and dev builds see them, end users never do.

Reach for `data-test-*` when no stable, semantic selector exists — the element has no meaningful class, no ARIA role, no text content you'd want to assert on, or the existing classes are tied to styling and could change. Don't sprinkle them on elements that already have a good selector; prefer asserting against user-visible structure when one exists.

```hbs
{{! Good - opaque element needs a test hook }}
<div data-test-empty-state-title>{{@title}}</div>
<div data-test-empty-state-body>{{@body}}</div>
```

Page objects then reference them like any other selector:

```rb
def has_title?(text)
  has_css?("[data-test-empty-state-title]", text: text)
end
```

Because the addon strips these in production, never use `data-test-*` for styling, JS behavior, or anything outside tests — those will disappear when users load the site.

## Page Objects

**Always use page objects** - never write raw selectors or Capybara finders directly in test files. Encapsulate all selectors and interactions in page object classes. Only add methods that are actually used by your tests - don't add methods speculatively.

**Design page object APIs from the call site.** Page object methods should make the spec read in product/user language. Prefer explicit methods and named arguments that describe the behavior being exercised over generic helpers that require the spec to know implementation details. If a test has to pass route/query param names, internal identifiers, selector fragments, enum values, or serialized keys, the page object abstraction has leaked. Keep that translation inside the page object so the spec remains stable when implementation details change.

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

## Assertors Must Use Capybara Matchers

**Page object assertors (`has_*?` / `have_no_*?` methods) must use Capybara's matchers (`has_css?`, `has_text?`, `has_selector?`, `has_field?`, `has_no_css?`, etc.). Never fetch a reference with `find` / `all` and then apply an equality matcher to it.**

Capybara matchers re-query the DOM on every retry up to `Capybara.default_max_wait_time`. Patterns that capture an element first and assert against it after bypass that re-query — the reference goes stale the moment the DOM updates (a re-render, an async response, an animation finishing) and the test flakes with `Selenium::WebDriver::Error::StaleElementReferenceError` or a value mismatch that disappears on rerun.

```rb
# Good - has_css? re-queries until it matches or times out
def has_username?(user)
  has_css?(".user-card .username", text: user.username)
end

def has_avatar_for?(user)
  has_css?(".user-card img.avatar[src='#{user.avatar_url}']")
end
```

```rb
# Bad - reference fetched once, equality applied after the fact
def has_username?(user)
  find(".user-card .username").text == user.username
end

# Bad - same problem with RSpec equality matchers on a fetched node
def has_avatar_for?(user)
  expect(find(".user-card img.avatar")[:src]).to eq(user.avatar_url)
end

# Bad - storing the node for later assertion
let(:username_el) { find(".user-card .username") }

it "shows the username" do
  expect(username_el.text).to eq(user.username) # stale the moment the card re-renders
end
```

The same rule applies to negative assertions. Use `has_no_css?` (or `expect(...).to have_no_css(...)` / `expect(...).not_to have_css(...)`, which RSpec routes through the matcher's waiting form). Never assert on the boolean negation of a positive predicate — `expect(!page.has_css?(...))` returns immediately and does not wait for the element to disappear.

```rb
# Good - waits for the element to be gone
def has_no_spinner?
  has_no_css?(".loading-spinner")
end

# Bad - returns false the moment the spinner exists, no waiting
def has_no_spinner?
  !has_css?(".loading-spinner")
end
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
