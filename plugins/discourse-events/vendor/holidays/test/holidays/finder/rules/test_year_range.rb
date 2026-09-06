require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/finder/rules/year_range'

class FinderRulesYearRangeTests < Test::Unit::TestCase
  def setup
    @year = 2015
    @year_ranges = {between: 1996..2002}
    @subject = Holidays::Finder::Rules::YearRange
  end

  def test_returns_error_if_target_year_is_missing
    assert_raises ArgumentError do
      @subject.call(nil, @year_ranges)
    end
  end

  def test_returns_error_if_target_year_is_not_a_number
    assert_raises ArgumentError do
      @subject.call("test", @year_ranges)
    end
  end

  def test_returns_error_if_year_ranges_if_nil
    @year_ranges = []
    assert_raises ArgumentError do
      @subject.call(@year, nil)
    end
  end

  def test_returns_error_if_year_ranges_contains_only_non_hash
    @year_ranges = :test
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_error_if_year_ranges_is_empty
    @year_ranges = [{}, {}]
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_error_if_year_range_contains_a_hash_with_multiple_entries
    @year_ranges = {:between => 1996..2002, :after => 2002}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_error_if_year_range_contains_unrecognized_operator
    @year_ranges = {:what => 2002}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_error_if_until_operator_and_value_is_not_a_number
    @year_ranges = {until: "bad"}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_true_if_until_operator_and_target_is_until
    @year_ranges = {until: 2000}
    assert_equal(true, @subject.call(1999, @year_ranges))
  end

  def test_returns_true_if_until_operator_and_target_is_equal
    @year_ranges = {until: 2000}
    assert_equal(true, @subject.call(2000, @year_ranges))
  end

  def test_returns_false_if_until_operator_and_target_is_after
    @year_ranges = {until: 2000}
    assert_equal(false, @subject.call(2001, @year_ranges))
  end

  def test_returns_error_if_from_operator_with_bad_value
    @year_ranges = {from: "bad"}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_false_if_from_operator_and_target_is_before
    @year_ranges = {from: 2000}
    assert_equal(false, @subject.call(1999, @year_ranges))
  end

  def test_returns_true_if_from_operator_and_target_is_equal
    @year_ranges = {from: 2000}
    assert_equal(true, @subject.call(2000, @year_ranges))
  end

  def test_returns_true_if_from_operator_and_target_is_after
    @year_ranges = {from: 2000}
    assert_equal(true, @subject.call(2001, @year_ranges))
  end

  def test_returns_error_if_limited_operator_and_bad_value
    @year_ranges = {limited: "bad"}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_error_if_limited_operator_with_empty_array
    @year_ranges = {limited: []}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_error_if_limited_operator_with_array_containing_non_integer_value
    @year_ranges = {limited: ["bad"]}
    assert_raises ArgumentError do
      @subject.call(@year, @year_ranges)
    end
  end

  def test_returns_true_if_limited_operator_and_value_is_number_that_matches_target
    @year_ranges = {limited: [2002]}
    assert_equal(true, @subject.call(2002, @year_ranges))
  end

  def test_returns_false_if_limited_operator_and_target_is_not_included
    @year_ranges = {limited: [1998,2000]}
    assert_equal(false, @subject.call(1997, @year_ranges))
    assert_equal(false, @subject.call(1999, @year_ranges))
    assert_equal(false, @subject.call(2002, @year_ranges))
  end

  def test_returns_true_if_limited_operator_and_target_is_included
    @year_ranges = {limited: [1998, 2000, 2002]}
    assert_equal(true, @subject.call(1998, @year_ranges))
    assert_equal(true, @subject.call(2000, @year_ranges))
    assert_equal(true, @subject.call(2002, @year_ranges))
  end

  def test_returns_error_if_between_operator_and_value_not_a_range
    @year_ranges = {between: 2000}
    assert_raises ArgumentError do
      @subject.call(2003, @year_ranges)
    end
  end

  def test_returns_false_if_between_operator_and_target_is_before
    @year_ranges = {between: 1998..2002}
    assert_equal(false, @subject.call(1997, @year_ranges))
  end

  def test_returns_true_if_between_operator_and_target_is_covered
    @year_ranges = {between: 1998..2002}
    assert_equal(true, @subject.call(1998, @year_ranges))
    assert_equal(true, @subject.call(2000, @year_ranges))
    assert_equal(true, @subject.call(2002, @year_ranges))
  end

  def test_returns_false_if_between_operator_and_target_is_after
    @year_ranges = {between: 1998..2002}
    assert_equal(false, @subject.call(2003, @year_ranges))
  end
end
