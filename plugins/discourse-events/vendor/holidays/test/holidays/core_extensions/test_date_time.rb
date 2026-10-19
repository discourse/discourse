require File.expand_path(File.dirname(__FILE__)) + '/../../test_helper'

require 'holidays/core_extensions/date'
require 'holidays/core_extensions/time'

class Date
  include Holidays::CoreExtensions::Date
end

class Time
  include Holidays::CoreExtensions::Time
end

class CoreExtensionDateTimeTests < Test::Unit::TestCase
  def setup
    @date = Date.civil(2008,1,1)
  end

  def test_change_method
    actual = @date.change(day: 5)
    assert_equal Date.civil(2008,1,5), actual

    actual = @date.change(year: 2016)
    assert_equal Date.civil(2016,1,1), actual

    actual = @date.change(month: 5)
    assert_equal Date.civil(2008,5,1), actual

    actual = @date.change(year: 2015, month: 5, day: 3)
    assert_equal Date.civil(2015,5,3), actual
  end

  def test_end_of_month_method
    # Works for month with 31 days
    actual = @date.end_of_month 
    assert_equal Date.civil(2008,1,31), actual

    # Works for month with 30 days
    actual = Date.civil(2008,9,5).end_of_month
    assert_equal Date.civil(2008,9,30), actual

    # Works for leap year
    actual = Date.civil(2016,2,1).end_of_month
    assert_equal Date.civil(2016,2,29), actual
  end

  def test_days_in_month_method
    # Works for month with 31 days
    actual = Time.days_in_month(1, 2008)
    assert_equal 31, actual

    # Works for month with 30 days
    actual = Time.days_in_month(9, 2008)
    assert_equal 30, actual

    # Works for leap year
    actual = Time.days_in_month(2, 2016)
    assert_equal 29, actual
  end
end
