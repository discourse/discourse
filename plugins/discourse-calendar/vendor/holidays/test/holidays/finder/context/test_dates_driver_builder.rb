require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/finder/context/dates_driver_builder'

class DatesDriverBuilderTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::Finder::Context::DatesDriverBuilder.new
  end

  def test_returns_appropriately_formatted_hash
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 31)

    dates_driver = @subject.call(start_date, end_date)

    assert(dates_driver.is_a?(Hash))

    dates_driver.each do |year, months|
      assert(year.is_a?(Integer))
      assert(months.is_a?(Array))
    end
  end

  def test_all_years_always_contains_variable_month
    start_date = Date.civil(2010, 1, 1)
    end_date = Date.civil(2020, 1, 1)

    dates_driver = @subject.call(start_date, end_date)

    assert(dates_driver[2010].include?(0))
    assert(dates_driver[2011].include?(0))
    assert(dates_driver[2012].include?(0))
    assert(dates_driver[2013].include?(0))
    assert(dates_driver[2014].include?(0))
    assert(dates_driver[2015].include?(0))
    assert(dates_driver[2016].include?(0))
    assert(dates_driver[2017].include?(0))
    assert(dates_driver[2018].include?(0))
    assert(dates_driver[2019].include?(0))
    assert(dates_driver[2020].include?(0))
  end

  def test_january_includes_february
    dates_driver = @subject.call(Date.civil(2015, 1, 1), Date.civil(2015, 1, 1))

    assert(dates_driver[2015].include?(1))
    assert(dates_driver[2015].include?(2))
  end

  def test_january_includes_previous_year_december
    dates_driver = @subject.call(Date.civil(2015, 1, 1), Date.civil(2015, 1, 1))

    assert(dates_driver[2015].include?(1))
    assert(dates_driver[2014].include?(12))
  end

  def test_december_includes_november
    dates_driver = @subject.call(Date.civil(2015, 12, 1), Date.civil(2015, 12, 1))

    assert(dates_driver[2015].include?(12))
    assert(dates_driver[2015].include?(11))
  end

  def test_december_includes_next_year_january
    dates_driver = @subject.call(Date.civil(2015, 12, 1), Date.civil(2015, 12, 1))

    assert(dates_driver[2015].include?(12))
    assert(dates_driver[2016].include?(1))
  end

  def test_middle_months_include_border_months
    dates_driver = @subject.call(Date.civil(2015, 5, 1), Date.civil(2015, 5, 1))
    assert(dates_driver[2015].include?(4))
    assert(dates_driver[2015].include?(5))
    assert(dates_driver[2015].include?(6))

    dates_driver = @subject.call(Date.civil(2015, 10, 1), Date.civil(2015, 10, 1))
    assert(dates_driver[2015].include?(9))
    assert(dates_driver[2015].include?(10))
    assert(dates_driver[2015].include?(11))

    dates_driver = @subject.call(Date.civil(2015, 3, 1), Date.civil(2015, 7, 1))
    assert(dates_driver[2015].include?(2))
    assert(dates_driver[2015].include?(3))
    assert(dates_driver[2015].include?(4))
    assert(dates_driver[2015].include?(5))
    assert(dates_driver[2015].include?(6))
    assert(dates_driver[2015].include?(7))
    assert(dates_driver[2015].include?(8))
  end
end
