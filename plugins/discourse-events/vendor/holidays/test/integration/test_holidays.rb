# encoding: utf-8
require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

class HolidaysTests < Test::Unit::TestCase
  def setup
    @date = Date.civil(2008,1,1)
  end

  def test_on
    h = Holidays.on(Date.civil(2008,9,1), :ca)
    assert_equal 'Labour Day', h[0][:name]

    holidays = Holidays.on(Date.civil(2008,7,4), :ca)
    assert_equal 0, holidays.length
  end

  def test_requires_valid_regions
    assert_raises Holidays::InvalidRegion do
      Holidays.on(Date.civil(2008,1,1), :xx)
    end

    assert_raises Holidays::InvalidRegion do
      Holidays.on(Date.civil(2008,1,1), [:ca,:xx])
    end

    assert_raises Holidays::InvalidRegion do
      Holidays.between(Date.civil(2008,1,1), Date.civil(2008,12,31), [:ca,:xx])
    end
  end

  def test_requires_valid_regions_holiday_next
    assert_raises Holidays::InvalidRegion do
      Holidays.next_holidays(1, [:xx], Date.civil(2008,1,1))
    end

    assert_raises Holidays::InvalidRegion do
      Holidays.next_holidays(1, [:ca,:xx], Date.civil(2008,1,1))
      Holidays.on(Date.civil(2008,1,1), [:ca,:xx])
    end

    assert_raises Holidays::InvalidRegion do
      Holidays.next_holidays(1, [:ca,:xx])
    end
  end

  def test_region_params
    holidays = Holidays.on(@date, :ca)
    assert_equal 1, holidays.length

    holidays = Holidays.on(@date, [:ca_bc,:ca])
    assert_equal 1, holidays.length
  end

  def test_observed_dates
    # Should fall on Tuesday the 1st
   assert_equal 1, Holidays.on(Date.civil(2008,7,1), :ca, :observed).length

    # Should fall on Monday the 2nd
    assert_equal 1, Holidays.on(Date.civil(2007,7,2), :ca, :observed).length
  end

  def test_any_region
    # Should return nothing(Victoria Day is not celebrated :ca wide anymore)
    holidays = Holidays.between(Date.civil(2008,5,1), Date.civil(2008,5,31), :ca)
    assert_equal 0, holidays.length

    # Should return Victoria Day and National Patriotes Day.
    #
    # Should be 2 in the CA region but other regional files are loaded during the
    # unit tests add to the :any count.
    holidays = Holidays.between(Date.civil(2008,5,1), Date.civil(2008,5,31), [:any])
    assert holidays.length >= 2

    # Test blank region
    holidays = Holidays.between(Date.civil(2008,5,1), Date.civil(2008,5,31))
    assert holidays.length >= 3
  end

  def test_any_region_holiday_next
    # Should return Victoria Day.
    holidays = Holidays.next_holidays(1, [:ca], Date.civil(2008,5,1))
    assert_equal 1, holidays.length
    assert_equal ['2008-07-01','Canada Day'] , [holidays.first[:date].to_s, holidays.first[:name].to_s]

    # Should return 2 holidays.
    holidays = Holidays.next_holidays(2, [:ca], Date.civil(2008,5,1))
    assert_equal 2, holidays.length

    # Should return 1 holiday in July
    holidays = Holidays.next_holidays(1, [:jp], Date.civil(2016, 5, 22))
    assert_equal ['2016-07-18','海の日'] , [holidays.first[:date].to_s, holidays.first[:name].to_s]

    # Must Region.If there is not region, raise ArgumentError.
    assert_raises ArgumentError do
      Holidays.next_holidays(2, '', Date.civil(2008,5,1))
    end
    # Options should be present.If they are empty, raise ArgumentError.
    assert_raises ArgumentError do
      Holidays.next_holidays(2, [], Date.civil(2008,5,1))
    end
    # Options should be Array.If they are not Array, raise ArgumentError.
    assert_raises ArgumentError do
      Holidays.next_holidays(2, :ca, Date.civil(2008,5,1))
    end
  end

  def test_year_holidays
    # Should return 7 holidays from February 23 to December 31
    holidays = Holidays.year_holidays([:ca_on], Date.civil(2016, 2, 23))
    assert_equal 7, holidays.length

    # Must have options (Regions)
    assert_raises ArgumentError do
      Holidays.year_holidays([], Date.civil(2016, 2, 23))
    end

    # Options must be in the form of an array.
    assert_raises ArgumentError do
      Holidays.year_holidays(:ca_on, Date.civil(2016, 2, 23))
    end
  end

  def test_year_holidays_with_specified_year
    # Should return all 11 holidays for 2016 in Ontario, Canada
    holidays = Holidays.year_holidays([:ca_on], Date.civil(2016, 1, 1))
    assert_equal 9, holidays.length

    # Should return all 5 holidays for 2016 in Australia
    holidays = Holidays.year_holidays([:au], Date.civil(2016, 1, 1))
    assert_equal 5, holidays.length
  end

  def test_year_holidays_without_specified_year
    # Gets holidays for current year from today's date
    holidays = Holidays.year_holidays([:de])
    assert_equal holidays.first[:date].year, Date.today.year
  end

  def test_year_holidays_empty
    # if remain holidays is nothing , method will return empty.
    holidays = Holidays.year_holidays([:ca_on], Date.civil(2016, 12, 27))
    assert_empty holidays
  end

  def test_year_holidays_random_years
    # Should be 1 less holiday, as Family day didn't exist in Ontario in 1990
    holidays = Holidays.year_holidays([:ca_on], Date.civil(1990, 1, 1))
    assert_equal 8, holidays.length

    # Family day still didn't exist in 2000
    holidays = Holidays.year_holidays([:ca_on], Date.civil(2000, 1, 1))
    assert_equal 8, holidays.length

    holidays = Holidays.year_holidays([:ca_on], Date.civil(2020, 1, 1))
    assert_equal 9, holidays.length

    holidays = Holidays.year_holidays([:ca_on], Date.civil(2050, 1, 1))
    assert_equal 9, holidays.length

    holidays = Holidays.year_holidays([:jp], Date.civil(2070, 1, 1))
    assert_equal 19, holidays.length
  end

  def test_sub_regions
    # Should return nothing (Victoria Day is no longer :ca wide)
    holidays = Holidays.between(Date.civil(2008,5,1), Date.civil(2008,5,31), :ca)
    assert_equal 0, holidays.length

    ## Should return National Patriotes Day.
    holidays = Holidays.between(Date.civil(2008,5,1), Date.civil(2008,5,31), :ca_qc)
    assert_equal 1, holidays.length

    # Should return Victoria Day and National Patriotes Day.
    holidays = Holidays.between(Date.civil(2008,5,1), Date.civil(2008,5,31), :ca_)
    assert_equal 3, holidays.length
  end

  def test_sub_regions_holiday_next
    # Should return Victoria Day.
    holidays = Holidays.next_holidays(2, [:ca_bc], Date.civil(2008,5,1))
    assert_equal 2, holidays.length
    assert_equal ['2008-05-19','Victoria Day'] , [holidays.first[:date].to_s, holidays.first[:name].to_s]

    # Should return Victoria Da and National Patriotes Day.
    holidays = Holidays.next_holidays(2, [:ca_qc], Date.civil(2008,5,1))
    assert_equal 2, holidays.length
    assert_equal ['2008-06-24','Fête Nationale'] , [holidays.last[:date].to_s, holidays.last[:name].to_s]

    # Should return Victoria Day and National Patriotes Day.
    holidays = Holidays.next_holidays(2, [:ca_], Date.civil(2008,5,1))
    assert_equal 2, holidays.length

    # Aparently something in jruby doesn't sort the same way as other rubies so....we'll just do it ourselves so
    # we don't flap.
    sorted_holidays = holidays.sort_by { |h| h[:name] }
    assert_equal ['2008-05-19','National Patriotes Day'] , [sorted_holidays.first[:date].to_s, sorted_holidays.first[:name].to_s]
    assert_equal ['2008-05-19','Victoria Day'] , [sorted_holidays.last[:date].to_s, sorted_holidays.last[:name].to_s]
  end

  def test_easter_lambda
    [Date.civil(1800,4,11), Date.civil(1899,3,31), Date.civil(1900,4,13),
     Date.civil(2008,3,21), Date.civil(2035,3,23)].each do |date|
      assert_equal 'Good Friday', Holidays.on(date, :ca)[0][:name]
    end

    [Date.civil(1800,4,14), Date.civil(1899,4,3), Date.civil(1900,4,16),
     Date.civil(2008,3,24), Date.civil(2035,3,26)].each do |date|
      assert_equal 'Easter Monday', Holidays.on(date, :ca_qc, :informal)[0][:name]
    end
  end

  def test_sorting
    (1..10).each{|year|
      (1..12).each{|month|
        holidays = Holidays.between(Date.civil(year, month, 1), Date.civil(year, month, 28), :gb_)
        holidays.each_with_index{|holiday, index|
          assert holiday[:date] >= holidays[index - 1][:date] if index > 0
        }
      }
    }
  end

  def test_caching
    good_friday = Date.civil(2008, 3, 21)
    easter_monday = Date.civil(2008, 3, 24)
    cache_end_date = Date.civil(2008, 3, 25)

    Holidays.cache_between(good_friday, cache_end_date, :ca, :informal)

    # Test that correct results are returned outside the
    # cache range, and with no caching
    assert_equal 1, Holidays.on(Date.civil(2035, 1, 1), :ca, :informal).length
    assert_equal 1, Holidays.on(Date.civil(2035, 1, 1), :us).length

    # Make sure cache is hit for all successive calls
    Holidays::Factory::Finder.expects(:between).never

    # Test that cache has been set and it returns the same as before
    assert_equal 1, Holidays.on(good_friday, :ca, :informal).length
    assert_equal 1, Holidays.on(easter_monday, :ca, :informal).length
    assert_equal 1, easter_monday.holidays(:ca, :informal).length
    assert_equal true, easter_monday.holiday?(:ca, :informal)
  end

  def test_load_all
    Holidays.load_all
    assert_equal 258, Holidays.available_regions.count
  end
end
