require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

class CustomYearRangeHolidaysTest < Test::Unit::TestCase

  def test_after_year_feature
    Holidays.load_custom('test/data/test_custom_year_range_holiday_defs.yaml')
    assert_equal [], Holidays.on(Date.civil(2015,6,1), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2016,6,1), :custom_year_range_file)
  end

  def test_before_year_feature
    Holidays.load_custom('test/data/test_custom_year_range_holiday_defs.yaml')
    assert_not_equal [], Holidays.on(Date.civil(2017,6,2), :custom_year_range_file)
    assert_equal [], Holidays.on(Date.civil(2018,6,2), :custom_year_range_file)
  end

  def test_between_year_feature
    Holidays.load_custom('test/data/test_custom_year_range_holiday_defs.yaml')
    assert_equal [], Holidays.on(Date.civil(2015,6,3), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2016,6,3), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2017,6,3), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2018,6,3), :custom_year_range_file)
    assert_equal [], Holidays.on(Date.civil(2019,6,3), :custom_year_range_file)
  end

  def test_limited_year_feature
    Holidays.load_custom('test/data/test_custom_year_range_holiday_defs.yaml')
    assert_equal [], Holidays.on(Date.civil(2015,6,4), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2016,6,4), :custom_year_range_file)
    assert_equal [], Holidays.on(Date.civil(2017,6,4), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2018,6,4), :custom_year_range_file)
    assert_not_equal [], Holidays.on(Date.civil(2019,6,4), :custom_year_range_file)
    assert_equal [], Holidays.on(Date.civil(2020,6,4), :custom_year_range_file)
  end
end
