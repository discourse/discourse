# frozen_string_literal: true

require "rails_helper"

RSpec.describe "System browser driver" do
  it "isolates browser state when the driver resets" do
    visit "/about"
    page.execute_script("localStorage.setItem('driver-reset', 'present')")
    page.execute_script("document.cookie = 'driver-reset=present; path=/'")
    page.driver.open_new_window(:tab)

    expect(page.driver.window_handles.length).to eq(2)

    page.driver.reset!
    visit "/about"

    expect(page.driver.window_handles.length).to eq(1)
    expect(page.evaluate_script("localStorage.getItem('driver-reset')")).to be_nil
    expect(page.evaluate_script("document.cookie.includes('driver-reset=')")).to eq(false)
  end

  it "captures JavaScript errors through the browser event API" do
    errors = Queue.new
    page.driver.on("pageerror", ->(error) { errors << error.message })
    visit "/about"
    page.execute_script("setTimeout(() => { throw new Error('driver event probe') }, 0)")

    expect(errors.pop(timeout: 5)).to include("driver event probe")
  end

  it "reloads the current page" do
    visit "/about"
    page.execute_script("document.body.dataset.driverReload = 'present'")

    page.refresh

    expect(page).to have_current_path("/about")
    expect(page.evaluate_script("document.body.dataset.driverReload")).to be_nil
  end

  it "removes browser profiles when startup fails" do
    profiles_before = Dir.glob(File.join(Dir.tmpdir, "discourse-{system,firefox}-*"))

    [
      [
        "DISCOURSE_SYSTEM_CHROMIUM_PATH",
        -> { DiscourseSystemDriver.new(nil, args: [], mobile: false) },
      ],
      ["DISCOURSE_SYSTEM_FIREFOX_PATH", -> { FirefoxBidiDriver.new(nil) }],
    ].each do |variable, build_driver|
      previous = ENV[variable]
      ENV[variable] = "/nonexistent/discourse-browser"
      expect { build_driver.call.with_browser_page { nil } }.to raise_error(Errno::ENOENT)
    ensure
      ENV[variable] = previous
    end

    expect(
      Dir.glob(File.join(Dir.tmpdir, "discourse-{system,firefox}-*")) - profiles_before,
    ).to be_empty
  end
end
