---
title: Write end-to-end system specs for the Discourse user interface
short_title: System specs
id: system-specs

---

## Background

Rails system specs are used to simulate the actions of a real user using the app in a browser. We use the `selenium-webdriver` which is what the latest version of Rails uses. The tests run locally and in CI out of the box. Capybara is the test framework used on top of `rspec` to interact with the web browser, and it sends commands to `selenium-webdriver`.
 
We currently only support running system specs in Chrome, make sure you have Chrome installed before proceeding. `selenium-webdriver` will download `chromedriver` based on your version of Chrome.

Since the Discourse app is an Ember Single Page Application, there are some unique constraints and challenges to writing system specs. It's important to keep in mind that you should always be observing for changes in the DOM in your tests, not manually waiting for things to happen or adding artificial sleep time. Also, the JavaScript build is separate from the Rails server, which means you must be running Ember CLI when writing system specs.

## Running system specs

Any system spec can be run with the `bin/rspec FILENAME.rb` command. By default the specs are run in a headless version of Chrome, meaning no browser window will open while the spec is running.

> :warning: If you do not already have the Discourse rails server running with `bin/ember-cli -u`, you will need to run `bin/ember-cli --build` after every JavaScript change to see these reflected in the headless browser. **It is recommended you just keep your local server running while writing system specs.**
>
> Also, ensure you run rails migrations any time you make modifications to your local database schema.

There are various environment flags that can be used to change how the spec is run.

### Commonly Used

* `SELENIUM_HEADLESS` - Set to `0` to open a browser while the spec is running. This will allow you to observe what is going on while the browser is being driven by the test harness. Combine with debugging tools and Chrome devtools to help write and debug specs.
* `CHROME_DEV_TOOLS` - Set to a position (`top|bottom|left|right`) to automatically open the Chrome devtools when a browser is launched with `SELENIUM_HEADLESS=0`. Greatly aids with debugging, since you can set `debugger` statements in any of our Ember code.
* `LOAD_PLUGINS` - If you are writing system specs for plugins you must set this to `1` and you must run the plugin system spec from your root discourse repo, e.g. `LOAD_PLUGINS=1 bin/rspec plugins/discourse-docs/spec/system/FILENAME.rb`

### Rarely Used

[details="These environment variables aren't often used but provide greater control over Selenium and Capybara"]
* `SELENIUM_BROWSER_LOG_LEVEL` - Controls the collection of browser logs (think e.g. `console.warn`, `console.info` and so on). Possible values are `OFF`, `SEVERE`, `WARNING`, `INFO`, `DEBUG`, `ALL`.
* `CAPYBARA_REMOTE_DRIVER_URL` - Allows Capybara to control a remote Chrome browser instead of a local one.
* `SELENIUM_VERBOSE_DRIVER_LOGS` - Show extra verbose logs of what Selenium is doing to communicate with the system tests. Most of the time this is unnecessary. You can enable this by setting it to `1`.
* `SELENIUM_DISABLE_VERBOSE_JS_LOGS` - By default JS logs are verbose, so errors from JS are shown when running system tests, you can disable this by setting it to `1`.
* `CAPYBARA_SERVER_HOST` - The hostname of the server that Selenium Webdriver is running on.
* `CAPYBARA_SERVER_PORT` - The port of the server that Selenium Webdriver is running on.
* `CAPYBARA_DEFAULT_MAX_WAIT_TIME` - Overrides the default wait time when looking for DOM elements in Capybara.
[/details]

## Writing system specs

### Basics
 
The bare minimum needed for a system spec is adding `type: :system` to the top level `describe` block of the spec. This makes sure RSpec uses Capybara et. al. via `rails_helper`.

```ruby
# frozen_string_literal: true

describe "Bookmarking posts and topics", type: :system do
  it "allows logged in user to create bookmarks with and without reminders" do
    # browser controls and rspec assertions go here
  end
end
```

If you need a logged in user you will need to fabricate one and sign them in. Our convention is to call the variable for the currently logged in user `current_user`:

```ruby
# frozen_string_literal: true

describe "Bookmarking posts and topics", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  before do
    sign_in(current_user)
  end

  it "allows logged in user to create bookmarks with and without reminders" do
    # browser controls and rspec assertions go here
  end
end
```

If you want to simulate a mobile device, you need only add `mobile: true` to the `it` block:

```ruby
context "when mobile"
  it "allows logged in user to create bookmarks with and without reminders", mobile: true do
    # browser controls and rspec assertions go here
  end
end
```

This will change the screen size with Capybara and `this.site.isMobileDevice` will be true in the Ember app, meaning some components will appear or behave differently.

### Best Practices

Many of these will be further expanded throughout this document, but this is a quick reference to come back to.

1. Remember that you should never manually sleep or wait for things in system specs, see the Gotchas section below
1. Do not store references to elements on the page in variables, they can quickly go "stale" in Selenium. Always `find` them again when you need them
1. Refactor system spec code into Page Objects once a repetitive pattern is apparent
1. RSpec expectations should be used very sparingly in Page Objects and preferably not at all, most expectations should be in the spec file 
1. Use high specificity CSS classes with BEM, these will aid in finding unique elements when writing system specs
1. Make sure you are testing the happy path only, no complicated `context` blocks and branching conditionals
1. Keep speed in mind, if a system test you have written is running quite slow investigate why and see if there are some things you can improve
1. Keep direct execution of JavaScript with things like `page.execute_script` to a minimum
1. Use `skip` or `xit` for tests that are known to be flaky in CI environments
1. Use Capybara and RSpec matchers effectively to avoid waiting too long or checking for an element too early, see Gotchas section below

### Capybara DSL and RSpec Matchers

Capybara has its own DSL which is accessible in every system spec and in every Page Object class, reference for this can be found at https://rubydoc.info/github/teamcapybara/capybara/master#the-dsl . A good cheat sheet can be found at https://devhints.io/capybara .

For example if you are looking for an element on the page you can use `find` with a CSS class:

```ruby
expect(find(".my-class")).to have_content(I18n.t("some.key"))
```

Most Capybara DSL supports passing in an optional `wait` parameter to override the default time that Capybara waits for an element or selector to be found in the DOM. This should be used rather than using things like sleep. This can be useful in cases where the backend takes a longer time to update the UI. For example:

```ruby
find(".some-element", wait: 10)
```

It's good practice to add CSS classes to elements as identifiers that have good specificity so your system specs are not finding other elements on the page by mistake. We use BEM for this.

This DSL is automatically included in all of our Page Objects, see the Page Object section below for more information.

### :warning: Gotchas

#### Capybara Selectors and Waiting

It is critically important to remember what https://rubydoc.info/github/teamcapybara/capybara/master#asynchronous-javascript-ajax-and-friends says . Never use this format of checking for an element or CSS on the page:

```ruby
expect(page.has_css?(".selector")).to eq(true)
expect(!page.has_css?(".selector")).to eq(true)
```

Always use these formats instead:

```ruby
expect(page/page_object).to have_css/have_custom_selector
expect(page/page_object).to have_no_css/have_custom_selector
```

This is because the latter format uses Capybara’s built in `wait` functionality whereas the former does not, this is important because we have an SPA with lots of AJAX calls, and we need to wait until a maximum timeout for elements or CSS to appear on the page.

Never manually wait for things to happen in a system spec using ruby's `sleep`!

#### Capybara Matcher DSL Negative Slowdowns

The same magic above that allows us to define our own `has_X` methods have some terrible speed implications when used in the `not_to` form. For example:

```ruby
expect(topic_page).not_to have_post_content(post)
```

This will cause an several seconds of time to be added to the spec. To fix this, we can write a negative DSL matcher directly in our Page Object and that does not take the same hit:

```ruby
def has_no_post_content?(post)
  post_by_number(post).has_no_content?(post.raw)
end

expect(topic_page).to have_no_post_content(post)
```

#### Using visit in a SPA

In Capybara, you can use `visit` to go directly to a page. For example:

```ruby
page.visit("/t/123")
```

This works fine in our Ember SPA for the initial navigation and page load. However, if you try to use it when navigating to other pages in specs, keep in mind that `visit` causes a full page refresh, clearing any UI state. To navigate to other pages it's generally best to click on a link directly:

```ruby
page.find(".some-link").click
```

### Page Objects

To make querying and inspecting parts of the page easier and reusable inbetween system specs, we are using the concept of Page Objects. A basic Page Object looks like this:

```ruby
# frozen_string_literal: true

module PageObjects
  module Pages
    class Tag < PageObjects::Pages::Base
      def visit_tag(tag)
        page.visit "/tag/#{tag.name}"
        self
      end

      def tag_info_btn
        find("#show-tag-info")
      end

      def add_synonyms_dropdown
        PageObjects::Components::SelectKit.new("#add-synonyms")
      end

      def search_tags(query)
        add_synonyms_dropdown.search(query)
      end

      def tag_box(tag)
        find(".tag-box div[data-tag-name='#{tag}']")
      end
    end
  end
end
```

Page Objects are responsible for the following:

* Visiting URLs, either directly or by clicking elements
* Finding common elements based on CSS selectors or XPaths
* Performing common actions in the UI (e.g. finding and clicking on a specific button)
* Filling in or otherwise interacting with input elements

We split our Page Objects into 3 classifications -- Page, Component, Modal.

* A "Page" here generally corresponds to an overarching Ember route, e.g. "Topic" for `/t/324345/some-topic`, and this contains logic for querying components within the topic such as "Posts". All of these inherit from `PageObjects::Pages::Base`.
* A "Modal" is any given modal window that opens within the app. All modal page objects inherit from `PageObjects::Modals::Base`, which handles open/closed states and clicking outside the modal.
* A "Component" is any reusable component in the Ember app and roughly maps to Ember components, though in some cases it may represent a small section of a Page. All of these inherit from `PageObjects::Components::Base`.

When using Page Objects inside system specs, you should use `let` to store instances of them in variables rather than defining them in your specs inline. The start of your spec file may look something like this:

```ruby
let(:modal) { PageObjects::Modals::Base.new }
let(:composer) { PageObjects::Components::Composer.new }
let(:topic) { PageObjects::Pages::Topic.new }
let(:cdp) { PageObjects::CDP.new }
```

Then, you can use these variables to interact with the page in a declarative way. For example:

```ruby
it "bookmarks a post" do
  topic_page.visit(topic.id)
  topic_page.bookmark_post(post.id)
  expect(topic_page.post_by_id(post.id)).to be_bookmarked
end
```

Generally a good rule of thumb to follow for creating Page Objects is to write your system spec without them first, then extract commonly referenced elements and actions into a Page Object for the corresponding page, component, or modal. Chrome DevTools and other debugging tools below are your friend in this process.

#### Capybara DSL and RSpec Matchers in Page Objects

All Capybara DSL is accessible in Page Objects because it is included in the base classes.

Every method we define inside Page Objects in the form `has_x?` magically :sparkles: becomes a custom RSpec matcher that respects Capybara's waiting logic. For example in bookmarks we have these matchers:

```ruby
def has_post_content?(post)
  post_by_number(post).has_content?(post.raw)
end

def has_post_bookmarked?(post)
  post_by_number(post).has_css?(".bookmarked")
end
```

Which are used like so inside system specs:

```ruby
expect(topic_page).to have_post_content(post)
expect(topic_page).to have_post_bookmarked(post)
```

The opposite is true as well -- you can define `has_no_X?` methods and they will do the opposite:

```ruby
def has_no_d_editor?
  page.has_no_css?(D_EDITOR_SELECTOR)
end
```

Which is used like so in a system spec:

```ruby
expect(category_page).to have_no_d_editor
```

Simple "boolean" methods like `open?`, `closed?` etc. will be usable as `.to be_x` RSpec matchers, which you can see the reference for at https://www.rubydoc.info/github/rspec/rspec-expectations/RSpec/Matchers . 

```ruby
def open?
  has_css?(".dialog-container")
end
```

Which is used like so in a system spec:

```ruby
expect(dialog).to be_open
```

## Discourse Secret Sauce :hamburger:

There are many Discourse-specific things to remember when writing system specs, whether they are commonly used helpers or general knowledge about the app and commonly used components. More may be added to this section over time.

### fab!

If you have used `let` and `let!` in RSpec before then you will have an inkling of what `fab!` might do:

* `fab!` will create an instance variable that is stored and used for _all_ the specs, rather than being recreated before each one like `let` is. This is very useful for things like a User or Topic that is used multiple times in the spec without modification in a `context` block.
* `fab!` can also be used with the name of a model, and it will use the default Fabricator for that model. For example `fab!(:topic)` is the equivalent to doing `fab!(:topic) { Fabricate(:topic) }`

You should use this whenever possible to avoid unnecessary database work.

### Spec Helpers

Most of these can be found in [SystemHelpers](https://github.com/discourse/discourse/blob/4157161578ebc72dae7a4d1a6905c2bee35aff85/spec/support/system_helpers.rb).

* `sign_in` - Directly posts to our `SessionController#become` endpoint, which only works in the test environment. Used if you need to log in as a user for a test.
* `try_until_success` - Wrap an RSpec expectation in this block and it will run every 0.1 seconds until the provided timeout, which by default is the Capybara default max wait time. This is useful for checking the database directly to see if a change has been applied or for various other things where it is tricky to find a DOM element that you can wait for in the UI. Should be used _sparingly_.
* `wait_for_attribute` - Waits for an attribute to equal a value on a specific DOM element. Uses `try_until_success` to wait for a maximum amount of time.
* `wait_for_animation` - Waits for an element to stop moving on the page, and for other animations to settle. Uses `try_until_success` to wait for a maximum amount of time.
* `resize_window` - Temporarily resizes the browser window to a specific width and height.
* `using_browser_timezone` - Sets the timezone of the browser to something different to your local timezone using a [TZ identifier](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) (e.g. `Africa/Algiers`)
* `setup_system_test` - Run automatically before every system spec, it sets various `SiteSetting` values that make sense, e.g. disabling "user tips" so they don't get in the way when searching for DOM elements.

### Common Components

For common components, we should utilize Page Objects heavily to abstract repeated behaviour. Below are some common components used widely throughout the app, what they do, and if possible a link to their Page Object class.

#### SelectKit

Used for all dropdowns, multiselects, and search fields in Discourse. See [PageObjects::Components::SelectKit](https://github.com/discourse/discourse/blob/4157161578ebc72dae7a4d1a6905c2bee35aff85/spec/system/page_objects/components/select_kit.rb). You must expand the dropdown, then select an item from it using a name or a value. You may also want to manually collapse it at times in the case of multiselects. Example usage:

```ruby
tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")
tag_chooser.expand
tag_chooser.select_row_by_name(tag2.name)
tag_chooser.collapse
```

#### Toasts

Quick messages shown on the screen based on a user action, which can be success, warning, info, or error. See [PageObjects::Components::Toasts](https://github.com/discourse/discourse/blob/4157161578ebc72dae7a4d1a6905c2bee35aff85/spec/system/page_objects/components/toasts.rb). Example usage:

```ruby
expect(toast).to have_success(I18n.t("some.success.message"))
```

#### Dialog

Messages shown to the user, which can be informative or require confirmation. See [PageObjects::Components::Dialog](https://github.com/discourse/discourse/blob/4157161578ebc72dae7a4d1a6905c2bee35aff85/spec/system/page_objects/components/dialog.rb). Example usage:

```ruby
expect(dialog).to be_open
dialog.click_yes
expect(dialog).to be_closed
```

There are many more examples in `spec/system/page_objects/components`.

### Plugins

Plugin system specs work in the same way as core system specs, but must be run from the directory of the discourse core repo, using the environment flag `LOAD_PLUGINS=1`.

### I18n

When comparing strings stored in our `server.en.yml` and `client.en.yml` localization files for expectations in system specs, you should use our `I18n` library.

If you need to use a string from `client.en.yml`, which is where the majority of user-facing strings are stored, you will need to prefix it with either `js.` or `admin_js.` depending on whether it is from the admin interface or the rest of the interface:

```ruby
# Admin string from client.en.yml
expect(sidebar).to have_no_section_link(
  I18n.t("admin_js.admin.community.sidebar_link.moderation_flags"),
)

# All other strings from client.en.yml
expect(find(".topic-list-header .static-label").text).to eq(
  I18n.t("js.filters.new.topics_with_count", count: 3),
)
```

#### Caveats

There are some caveats and situations where you don't need to do this. For **user-generated** or **fabricated** strings, this is not necessary.

```ruby
# Fabricated strings
fab!(:topic) { Fabricate(:topic, title: "Best topic ever!")

it "checks the topic title" do
  # Using a fabricated string directly
  expect(topic_page).to have_title(topic.title)
 
  # Also acceptable
  expect(topic_page).to have_title("Best topic ever!")
end


# User-generated strings
it "closes topics with message" do
  # Filling in a user-generated string
  topic_bulk_actions_modal.fill_in_close_note("None of these are useful")
  topic_bulk_actions_modal.click_bulk_topics_confirm

  # Check that the topic now has the message, which is user-generated content
  visit("/t/#{topic.slug}/#{topic.id}")
  expect(topic_page).to have_content("None of these are useful")
end
```

Finally, some strings are quite big and there's no need to check that the entire contents are on the page and match correctly. In that case, matching part of the string with direct comparison is fine.

### Rate Limiting

Our `RateLimiter` system is disabled by default in specs. However if you need to turn it on to test some rate limiting specifically in system specs (though you should use request specs for this), use `RateLimiter.enable`.

## Advanced Chrome Interaction

In certain cases you will need to use some advanced features of Chrome in your system specs. Some examples are interacting with the clipboard (copy and paste) and network manipulation (simulating slow connections). This is achieved using the [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/), and sometimes with native Capybara functionality.

These advanced interactions are all stored in the `PageObjects::CDP` class.

### Clipboard example:

```ruby
it "allows copying message transcripts" do
  cdp.allow_clipboard
  chat_page.visit_channel(channel_1)
  channel_page.messages.copy_text(message_1)
  expect(cdp.read_clipboard.chomp).to eq(message_1.message)
end
```

### Network example:

```ruby
it "allows cancelling uploads" do
  visit("/new-topic")
  expect(composer).to be_opened

  file_path_1 = file_from_fixtures("huge.jpg", "images").path
  cdp.with_slow_upload do
    attach_file(file_path_1) { composer.click_toolbar_button("upload") }
    expect(composer).to have_in_progress_uploads
    find("#cancel-file-upload").click

    expect(composer).to have_no_in_progress_uploads
    expect(composer.preview).to have_no_css(".image-wrapper")
  end
end
```

### Direct JavaScript Execution

You can also directly run arbitrary JavaScript code in the browser with Capybara though this should be done sparingly, since Ember manages the lifecycle of the app. If you must, you can do it like so:

```ruby
page.execute_script(<<~JS)
  alert("Look ma, JavaScript!");
JS
```

## Debugging

Writing and debugging system specs can be tricky at times, especially when they become "flaky" and start failing in strange ways. These debugging tools help with writing the specs in the first place and figuring out what is wrong.

* `pause_test` - This helper can be used in your spec to pause execution using `binding.pry` so you can inspect the page and other local spec variables. You can resume execution when done. When used in conjunction with `CHROME_DEV_TOOLS=bottom` and `SELENIUM_HEADLESS=0` this becomes a powerful debugging tool.
* `debugger` and `{{debugger}}` - If you are using `CHROME_DEV_TOOLS` and `SELENIUM_HEADLESS=0` then any JavaScript debug breakpoints will be hit in the browser. The Ember `{{debugger}}` helper in templates works as well.
* Screenshots - Every time a system spec fails Capybara will produce a screenshot, typically in the `$REPO/tmp/capybara` directory. You can also manually call `save_screenshot` inside your spec to do this.
* `save_and_open_page` - Use this to dump the current HTML of the page and open it in your browser.

### Getting screenshots from Github Actions

For system test failures in Github Actions Runners, there are screenshots we can download from job artifacts. In the job's summary, artifacts are located at the bottom.

[details="Screenshots on how to get there"]
![GitHub CI system spec errors](/assets/failing_ci_system_spec_1.png)

![GitHub actions summary](/assets/failing_ci_system_spec_2.png)

![GitHub actions artifacts](/assets/failing_ci_system_spec_3.png)
[/details]
