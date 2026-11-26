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
  # Offset Date.now while allowing browser timers and the Ember run loop to advance.
  def self.freeze(page, time)
    page.driver.with_browser_page { |browser_page| browser_page.clock.install(time:) }
  end

  def self.override_timezone(browser_page, timezone)
    browser_page.override_timezone(timezone)
  end
end
