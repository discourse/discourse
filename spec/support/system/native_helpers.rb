# frozen_string_literal: true
module PlaywrightMatchers
  extend Playwright::Test::Matchers
end

class SystemBrowserSynchronization
  def self.wait_for_resize(page)
    page.evaluate(<<~JS)
      () => new Promise(resolve => {
        requestAnimationFrame(() => requestAnimationFrame(resolve));
      })
    JS
    SystemBrowserBootstrap.wait_for(page)
  end

  def self.wait_for(page)
    page.wait_for_function(
      <<~JS,
      async timeout => {
        if (window.clientSettled) {
          await window.clientSettled(timeout);
        }
        return true;
      }
    JS
      arg: Capybara.default_max_wait_time * 1000,
      timeout: Capybara.default_max_wait_time * 1100,
    ).dispose
  end
end

class SystemBrowserBootstrap
  def self.wait_for(page)
    result =
      page.wait_for_function(
        "() => !document.querySelector('discourse-assets') || Boolean(document.querySelector('#main.ember-application'))",
        timeout: Playwright::Test.expect_timeout,
      )
    result.dispose
    SystemBrowserSynchronization.wait_for(page)
  end
end

module NativeBrowserApplicationSynchronization
  %i[
    click
    dblclick
    press
    press_sequentially
    fill
    check
    uncheck
    set_checked
    hover
    drag_to
    scroll_into_view_if_needed
    dispatch_event
    select_option
    set_input_files
  ].each do |method_name|
    define_method(method_name) do |*args, **options|
      result = super(*args, **options)
      SystemBrowserSynchronization.wait_for(page)
      result
    end
  end
end

Playwright::Locator.prepend(NativeBrowserApplicationSynchronization)

module NativeBrowserMatcherGuard
  private

  def wrap(actual)
    if RSpec.current_example&.metadata&.[](:native_playwright)
      raise TypeError, "#{self.class} cannot check #{actual.class} in a direct Playwright example"
    end

    super
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    if ENV["DIRECT_PLAYWRIGHT_ONLY"] == "1"
      Capybara::RSpecMatchers::Matchers::WrappedElementMatcher.prepend(NativeBrowserMatcherGuard)
    end
  end
end

module NativeSystemHelpers
  BROWSER_KEY_NAMES = {
    control: "Control",
    ctrl: "Control",
    meta: "Meta",
    shift: "Shift",
    alt: "Alt",
    enter: "Enter",
    return: "Enter",
    escape: "Escape",
    tab: "Tab",
    space: "Space",
    up: "ArrowUp",
    down: "ArrowDown",
    left: "ArrowLeft",
    right: "ArrowRight",
    home: "Home",
    end: "End",
    backspace: "Backspace",
    delete: "Delete",
  }.freeze
  private_constant :BROWSER_KEY_NAMES

  def browser_text_pattern(value)
    value.is_a?(Regexp) ? value : value.to_s
  end

  def browser_exact_text_pattern(value)
    words = value.to_s.split.map { |word| Regexp.escape(word) }
    Regexp.new("^\\s*#{words.join('\\s+')}\\s*$")
  end

  def browser_key_chord(keys)
    keys.flatten.map { |key| BROWSER_KEY_NAMES.fetch(key, key.to_s) }.join("+")
  end

  def native_browser
    NativeSystemBrowser.for_example(RSpec.current_example)
  end

  def reset_browser_sessions
    NativeSystemBrowser.reset_for(RSpec.current_example)
    Capybara.reset_sessions!
    native_browser.start(RSpec.current_example, base_url: Capybara.current_session.server.base_url)
  end

  def browser_page
    native_browser.page
  end

  def browser_root
    native_browser.root
  end

  def browser_content
    root = browser_root
    root.is_a?(Playwright::Page) ? root.locator("body") : root
  end

  def has_displayed_content?(content, wait: Capybara.default_max_wait_time, exact: false, **)
    value = content.is_a?(Regexp) ? content : content.to_s
    matcher =
      (
        if exact
          PlaywrightMatchers.have_text(value, useInnerText: true, timeout: wait * 1000)
        else
          PlaywrightMatchers.contain_text(value, useInnerText: true, timeout: wait * 1000)
        end
      )
    matcher.matches?(browser_content)
  end

  def has_no_displayed_content?(content, wait: Capybara.default_max_wait_time, exact: false, **)
    value = content.is_a?(Regexp) ? content : content.to_s
    matcher =
      (
        if exact
          PlaywrightMatchers.have_text(value, useInnerText: true, timeout: wait * 1000)
        else
          PlaywrightMatchers.contain_text(value, useInnerText: true, timeout: wait * 1000)
        end
      )
    matcher.does_not_match?(browser_content)
  end

  def has_displayed_text?(content, wait: Capybara.default_max_wait_time, exact: false, **)
    value = content.is_a?(Regexp) ? content : content.to_s
    matcher =
      (
        if exact
          PlaywrightMatchers.have_text(value, useInnerText: true, timeout: wait * 1000)
        else
          PlaywrightMatchers.contain_text(value, useInnerText: true, timeout: wait * 1000)
        end
      )
    matcher.matches?(browser_content)
  end

  def has_no_displayed_text?(content, wait: Capybara.default_max_wait_time, exact: false, **)
    value = content.is_a?(Regexp) ? content : content.to_s
    matcher =
      (
        if exact
          PlaywrightMatchers.have_text(value, useInnerText: true, timeout: wait * 1000)
        else
          PlaywrightMatchers.contain_text(value, useInnerText: true, timeout: wait * 1000)
        end
      )
    matcher.does_not_match?(browser_content)
  end

  def browser_arguments(*arguments)
    arguments.map do |argument|
      argument.is_a?(Playwright::Locator) ? argument.element_handle : argument
    end
  end

  def drag_browser_element(source:, target:, delay_seconds:)
    source.scroll_into_view_if_needed
    position = source.bounding_box
    browser_page.mouse.move(
      position["x"] + position["width"] / 2,
      position["y"] + position["height"] / 2,
    )
    browser_page.mouse.down
    target.scroll_into_view_if_needed
    sleep delay_seconds
    position = target.bounding_box
    browser_page.mouse.move(
      position["x"] + position["width"] / 2,
      position["y"] + position["height"] / 2,
      steps: 6,
    )
    sleep delay_seconds
    browser_page.mouse.up
    sleep delay_seconds
  end

  def within_browser(locator, wait_state: "visible", &block)
    if locator.is_a?(String)
      locator = browser_root.locator(locator)
      locator = locator.filter(visible: true) if wait_state == "visible"
    end
    native_browser.within_scope(locator, wait_state: wait_state, &block)
  end

  def using_browser_session(name)
    NativeSystemBrowser.using_session(name) do
      native_browser.start(
        RSpec.current_example,
        base_url: Capybara.current_session.server.base_url,
      )
      yield
    end
  end

  def using_browser_page(page)
    previous = browser_page
    native_browser.switch_page(page)
    yield
  ensure
    native_browser.switch_page(previous)
  end

  def sign_in(user)
    browser_page
      .goto(
        File.join(
          GlobalSetting.relative_url_root || "",
          "/session/#{user.encoded_username}/become.json?redirect=false",
        ),
      )
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_page.locator("body")).to PlaywrightMatchers.contain_text(
      "Signed in to #{user.encoded_username} successfully",
    )
  end

  private

  def save_image
    FileUtils.mkdir_p(File.dirname(absolute_image_path))
    browser_page.screenshot(path: absolute_image_path.to_s)
  end

  def save_html
    FileUtils.mkdir_p(File.dirname(absolute_html_path))
    File.write(absolute_html_path, browser_page.content)
  end
end
