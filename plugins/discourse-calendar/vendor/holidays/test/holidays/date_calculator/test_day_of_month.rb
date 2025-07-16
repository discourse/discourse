require File.expand_path(File.dirname(__FILE__)) + '/../../test_helper'

require 'holidays/date_calculator/day_of_month'

class DayOfMonthDateCalculatorTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::DateCalculator::DayOfMonth.new
  end

  def test_call_returns_expected_results
    assert_equal 7, @subject.call(2008, 1, :first, :monday)
    assert_equal 18, @subject.call(2008, 12, :third, :thursday)
    assert_equal 28, @subject.call(2008, 1, :last, 1)
  end

  def test_returns_argument_error_with_invalid_week_parameter
    assert_raises ArgumentError do
      @subject.call(2008, 1, :wrong_week_argument, :monday)
    end
  end

  def test_returns_argument_error_with_invalid_day_parameter
    assert_raises ArgumentError do
      @subject.call(2008, 1, :first, :bad_wday)
    end
  end
end
