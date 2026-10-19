require File.expand_path(File.dirname(__FILE__)) + '/../../test_helper'

require 'date'
require 'holidays/core_extensions/date'

class Date
  include Holidays::CoreExtensions::Date
end

class CoreExtensionDateTests < Test::Unit::TestCase
  def setup
    @date = Date.civil(2008,1,1)
  end

  def test_extending_date_class
    assert @date.respond_to?('holidays')
    assert @date.respond_to?('holiday?')
  end

  def test_extending_datetime_class
    dt = DateTime.civil(2008,1,1)
    assert dt.respond_to?('holidays')
    assert dt.respond_to?('holiday?')
  end

  def test_calculating_mdays
    # US Memorial day
    assert_equal 29, Date.calculate_mday(2006, 5, :last, 1)
    assert_equal 28, Date.calculate_mday(2007, 5, :last, 1)
    assert_equal 26, Date.calculate_mday(2008, 5, :last, 1)
    assert_equal 25, Date.calculate_mday(2009, 5, :last, 1)
    assert_equal 31, Date.calculate_mday(2010, 5, :last, 1)
    assert_equal 30, Date.calculate_mday(2011, 5, :last, 1)
    
    # Labour day
    assert_equal 3, Date.calculate_mday(2007, 9, :first, 1)
    assert_equal 1, Date.calculate_mday(2008, 9, :first, :monday)
    assert_equal 7, Date.calculate_mday(2009, 9, :first, 1)
    assert_equal 5, Date.calculate_mday(2011, 9, :first, 1)
    assert_equal 5, Date.calculate_mday(2050, 9, :first, 1)
    assert_equal 4, Date.calculate_mday(2051, 9, :first, 1)
    
    # Canadian thanksgiving
    assert_equal 8, Date.calculate_mday(2007, 10, :second, 1)
    assert_equal 13, Date.calculate_mday(2008, 10, :second, :monday)
    assert_equal 12, Date.calculate_mday(2009, 10, :second, 1)
    assert_equal 11, Date.calculate_mday(2010, 10, :second, 1)

    # Misc
    assert_equal 21, Date.calculate_mday(2008, 1, :third, 1)
    assert_equal 1, Date.calculate_mday(2007, 1, :first, 1)
    assert_equal 2, Date.calculate_mday(2007, 3, :first, :friday)
    assert_equal 30, Date.calculate_mday(2012, 1, :last, 1)
    assert_equal 29, Date.calculate_mday(2016, 2, :last, 1)
    
    # From end of month
    assert_equal 26, Date.calculate_mday(2009, 8, -1, :wednesday)
    assert_equal 19, Date.calculate_mday(2009, 8, -2, :wednesday)
    assert_equal 12, Date.calculate_mday(2009, 8, -3, :wednesday)
    
    assert_equal 13, Date.calculate_mday(2008, 8, -3, :wednesday)
    assert_equal 12, Date.calculate_mday(2009, 8, -3, :wednesday)
    assert_equal 11, Date.calculate_mday(2010, 8, -3, :wednesday)
    assert_equal 17, Date.calculate_mday(2011, 8, -3, :wednesday)
    assert_equal 15, Date.calculate_mday(2012, 8, -3, :wednesday)
    assert_equal 14, Date.calculate_mday(2013, 8, -3, :wednesday)
  end

  def test_mday_allows_integers_or_symbols
    assert_nothing_raised do
      Date.calculate_mday(2008, 1, 1, 1)
    end

    assert_nothing_raised do
      Date.calculate_mday(2008, 1, -1, 1)
    end

    assert_nothing_raised do
      Date.calculate_mday(2008, 1, :last, 1)
    end
  end

  def test_mday_requires_valid_week
    assert_raises ArgumentError do
      Date.calculate_mday(2008, 1, :none, 1)
    end

    assert_raises ArgumentError do
      Date.calculate_mday(2008, 1, nil, 1)
    end

    assert_raises ArgumentError do
      Date.calculate_mday(2008, 1, 0, 1)
    end
  end

  def test_mday_requires_valid_day
    assert_raises ArgumentError do
      Date.calculate_mday(2008, 1, 1, :october)
    end

    assert_raises ArgumentError do
      Date.calculate_mday(2008, 1, 1, nil)
    end

    assert_raises ArgumentError do
      Date.calculate_mday(2008, 1, 1, 7)
    end
  end

  def test_date_holiday?
    assert Date.civil(2008,1,1).holiday?('ca')
    assert Date.today.holiday?('test')
  end

  def test_datetime_holiday?
    # in situations with activesupport
    assert DateTime.civil(2008, 1, 1).to_date.holiday?('ca')
    assert DateTime.civil(2008, 1, 1).holiday?('ca')
  end

end
