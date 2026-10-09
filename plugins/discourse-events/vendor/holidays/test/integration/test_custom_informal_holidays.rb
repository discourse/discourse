require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

class CustomHolidaysTest < Test::Unit::TestCase

  def test_custom_region_informal_day_parsing
    Holidays.load_custom('test/data/test_custom_informal_holidays_defs.yaml')

    assert_not_equal [], Holidays.on(Date.new(2018,1,1), :custom_informal, :informal)
    assert_equal [], Holidays.on(Date.new(2018,1,1), :custom_informal, :observed)

    assert_not_equal [], Holidays.on(Date.new(2018,1,5), :custom_informal, :informal)
    assert_equal [], Holidays.on(Date.new(2018,1,5), :custom_informal, :observed)
  end

end
