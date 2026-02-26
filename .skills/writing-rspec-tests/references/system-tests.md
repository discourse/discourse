# System Tests

Discourse uses Rails system tests with RSpec and Capybara. Tests run both server and client code together.

## File Naming

Use `action_scenario_spec.rb` pattern - describe what the test does:
- `filter_sidebar_spec.rb` → `RSpec.describe "Filter sidebar"`
- `toggle_dark_mode_spec.rb` → `RSpec.describe "Toggle dark mode"`
- `create_topic_with_template_spec.rb` → `RSpec.describe "Create topic with template"`

Avoid generic names like `feature_spec.rb` or `my_feature_spec.rb`.

## Test Structure

```rb
# frozen_string_literal: true

RSpec.describe "Filter sidebar", system: true do
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

**Required:** The `system: true` metadata on the describe block.

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
