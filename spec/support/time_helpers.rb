# frozen_string_literal: true

# Time / clock control for specs.

class TrackTimeStub
  def self.stubbed
    false
  end
end

module TimeHelpers
  # Time.now can cause flaky tests, especially in cases like
  # leap days. This method freezes time at a "safe" specific
  # time (the Discourse 1.1 release date), so it will not be
  # affected by further temporal disruptions.
  def freeze_time_safe
    freeze_time(DateTime.parse("2014-08-26 12:00:00"))
  end

  def freeze_time(now = Time.now)
    time = now
    datetime = now

    if Time === now
      datetime = now.to_datetime
    elsif DateTime === now
      time = now.to_time
    else
      datetime = DateTime.parse(now.to_s)
      time = Time.parse(now.to_s)
    end

    if block_given?
      raise "nested freeze time not supported" if TrackTimeStub.stubbed
    end

    DateTime.stubs(:now).returns(datetime)
    Time.stubs(:now).returns(time)
    Date.stubs(:today).returns(datetime.to_date)
    TrackTimeStub.stubs(:stubbed).returns(true)

    if block_given?
      begin
        yield
      ensure
        unfreeze_time
      end
    else
      time
    end
  end

  def unfreeze_time
    DateTime.unstub(:now)
    Time.unstub(:now)
    Date.unstub(:today)
    TrackTimeStub.unstub(:stubbed)
  end
end

module BrowserTime
  # Install the clock at the desired time and immediately resume it so
  # the browser starts at `time` but `Date.now()` keeps advancing with the
  # wall clock.
  #
  # `set_fixed_time` pins `Date.now()` forever, which breaks Ember's runloop: `next()`/`later()`
  # schedule timers via `Date.now() + wait` and only fire them once
  # `Date.now()` has advanced past that, so any action deferred through
  # the runloop (e.g. DButton, which uses `next()` to optimise INP)
  # would silently never run.
  #
  # Playwright warns about this "stuck page" behaviour for pinned clocks too.
  def self.freeze(page, time)
    page.driver.with_playwright_page do |pw_page|
      pw_page.clock.install(time:)
      pw_page.clock.resume
    end
  end

  # Apply timezone override via CDP if timezone metadata is present.
  # We use CDP instead of the driver's timezoneId option because the driver
  # instance is cached and reused between tests, so timezoneId only affects
  # the first test. CDP override works at runtime for each test.
  def self.override_timezone(pw_page, timezone)
    cdp = pw_page.context.new_cdp_session(pw_page)
    cdp.send_message("Emulation.setTimezoneOverride", params: { timezoneId: timezone })
  end
end
