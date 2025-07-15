require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/repository/proc_result_cache'

class ProcResultCacheRepoTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::Definition::Repository::ProcResultCache.new
  end

  def test_lookup_stores_and_returns_result_of_function_if_it_is_not_present
    function = lambda { |year| Date.civil(year, 2, 1) - 1 }
    function_argument = 2015

    assert_equal(Date.civil(2015, 1, 31), @subject.lookup(function, function_argument))
  end

  #FIXME This test stinks. I don't know how to show that the second invocation
  #      doesn't call the function. In rspec I could just do an expect().not_to
  #      but it doesn't seem like Mocha can do that? I'm punting.
  def test_lookup_simply_returns_result_of_cache_if_present_after_first_call
    function = lambda { |year| Date.civil(year, 2, 1) - 1 }
    function_argument = 2015

    assert_equal(Date.civil(2015, 1, 31), @subject.lookup(function, function_argument))
  end

  def test_lookup_raises_error_if_function_is_not_a_proc
    function = "Holidays.easter(year)"
    function_argument = 2015

    assert_raise ArgumentError do
      @subject.lookup(function, function_argument)
    end
  end

  def test_lookup_accepts_date_as_function_argument
    function = lambda { |date| date - 1 }
    function_argument = Date.civil(2015, 2, 1)

    assert_equal(Date.civil(2015, 1, 31), @subject.lookup(function, function_argument))
  end

  def test_lookup_accepts_symbol_as_function_argument
    function = lambda { |symbol| symbol }
    function_argument = :test

    assert_equal(:test, @subject.lookup(function, function_argument))
  end

  def test_accepts_multiple_arguments_for_functions
    function = lambda { |year, month, day| Date.civil(year, month, day) + 1 }
    year = 2016
    month = 1
    day = 1

    assert_equal(Date.civil(2016, 1, 2), @subject.lookup(function, year, month, day))
  end

  def test_raises_error_if_one_of_multiple_arguments_is_not_an_int_or_date
    function = lambda { |year, month, day| Date.civil(year, month, day) + 1 }
    year = 2016
    month = 1
    day = "1"

    assert_raise ArgumentError do
     @subject.lookup(function, year, month, day)
    end
  end

  def test_accepts_mix_of_integers_and_dates_for_multiple_function_arguments
    function = lambda { |date, modifier| date + modifier }
    date = Date.civil(2016, 1, 1)
    modifier = 5

    assert_equal(Date.civil(2016, 1, 6), @subject.lookup(function, date, modifier))
  end

  def test_lookup_raises_error_if_function_argument_is_not_valid
    function = lambda { |year| Date.civil(year, 2, 1) - 1 }
    function_argument = "2015"

    assert_raise ArgumentError do
      @subject.lookup(function, function_argument)
    end

    function_argument = Proc.new { |arg1| "arg1" + "something"}
    assert_raise ArgumentError do
      @subject.lookup(function, function_argument)
    end
  end
end
