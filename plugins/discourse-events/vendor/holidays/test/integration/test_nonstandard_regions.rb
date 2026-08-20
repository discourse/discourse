# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

class NonstandardRegionsHolidaysTests < Test::Unit::TestCase
  def test_ecbtarget_christmas_day
    h = Holidays.on(Date.new(2018,12,25), :ecbtarget)
    assert_equal 'Christmas Day', h[0][:name]
  end

  def test_federalreserve_memorial_day
    h = Holidays.on(Date.new(2018,5,28), :federalreserve)
    assert_equal 'Memorial Day', h[0][:name]

  end

  def test_federalreservebanks_independence_day
    h = Holidays.on(Date.new(2019,7,4), :federalreservebanks, :observed)
    assert_equal 'Independence Day', h[0][:name]
  end

  def test_unitednations_international_day_of_families
    h = Holidays.on(Date.new(2021,5,15), :unitednations)
    assert_equal 'International Day of Families', h[0][:name]
  end
end
