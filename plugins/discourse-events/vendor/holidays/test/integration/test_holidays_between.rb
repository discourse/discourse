require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

require "#{Holidays::DEFINITIONS_PATH}/ca"

# Re-include CA defs via holidays/north_america to ensure that individual
# defs aren't duplicated.
#
# NOTE: this test is a mixture of integration and unit tests. It's messy and bad.
# I am not fixing it here because I am trying to clean up the 'between' use case
# and don't want to bite off more than I can chew.
require "#{Holidays::DEFINITIONS_PATH}/northamerica"

class HolidaysBetweenTests < Test::Unit::TestCase
  def setup
    @date = Date.civil(2008,1,1)
    @subject = Holidays.method(:between)
  end

  def teardown
    Holidays::Factory::Definition.cache_repository.reset!
  end

  def test_between
    holidays = @subject.call(Date.civil(2008,7,1), Date.civil(2008,7,1), :ca)
    assert_equal 1, holidays.length

    holidays = @subject.call(Date.civil(2008,7,1), Date.civil(2008,7,31), :ca)
    assert_equal 1, holidays.length

    holidays = @subject.call(Date.civil(2008,7,2), Date.civil(2008,7,31), :ca)
    assert_equal 0, holidays.length
  end

  def test_between_raises_error_if_missing_start_or_end_date
    assert_raise ArgumentError do
      @subject.call(nil, Date.civil(2015, 1, 1), :us)
    end

    assert_raise ArgumentError do
      @subject.call(Date.civil(2015, 1, 1), nil, :us)
    end
  end

  def test_between_raises_error_if_end_date_is_before_start_date
    assert_raise ArgumentError do
      @subject.call(Date.civil(2019, 2, 1), Date.civil(2019, 1, 1), :us)
    end

    assert_raise ArgumentError do
      @subject.call(Date.civil(2008,7,2), Date.civil(2000,7,2), :ca)
    end
  end

  def test_cached_holidays_are_returned_if_present
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 31)
    options = [:us, :informal]

    Holidays::Factory::Definition.cache_repository.expects(:find).with(start_date, end_date, options).returns({cached: 'data'})

    assert_equal({cached: 'data'}, @subject.call(start_date, end_date, *options))
  end

  def test_options_are_parsed
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 31)
    options = [:us]

    between_mock = mock()
    Holidays::Factory::Finder.stubs(:between).returns(between_mock)
    between_mock.expects(:call).with(start_date, end_date, [:us])

    @subject.call(start_date, end_date, *options)
  end

  def test_dates_driver_builder_is_called
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 31)
    options = [:us]

    between_mock = mock()
    Holidays::Factory::Finder.stubs(:between).returns(between_mock)
    between_mock.expects(:call).with(start_date, end_date, [:us])

    @subject.call(start_date, end_date, *options)
  end
end
