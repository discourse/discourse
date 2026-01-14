require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/context/function_processor'

class FunctionProcessorTests < Test::Unit::TestCase
  def setup
    @year = 2016
    @month = 1
    @day = 15
    @region = :test
    @input = { year: @year, month: @month, day: @day, region: @region }

    @func_id = "custom_function_id"
    @func_args = [:year]
    @func_modifier = 1

    @custom_methods_repo = mock()
    @proc_result_cache_repo = mock()

    @custom_func = mock()

    @custom_methods_repo.expects(:find).at_most_once.with(@func_id).returns(@custom_func)
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns(Date.civil(@year, @month, @day))

    @subject = Holidays::Definition::Context::FunctionProcessor.new(
      @custom_methods_repo,
      @proc_result_cache_repo,
    )
  end

  def test_no_function_arguments_returns_error
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, nil, @func_modifier)
    end

    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [], @func_modifier)
    end
  end

  def test_unknown_function_argument_returns_error
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:something], @func_modifier)
    end
  end

  def test_unknown_function_id_returns_error
    bad_id = "some-bad-id"
    @custom_methods_repo.expects(:find).at_most_once.with(bad_id).returns(nil)

    assert_raises Holidays::FunctionNotFound do
      @subject.call(@input, bad_id, @func_args, @func_modifier)
    end
  end

  def test_year_arg_passed_to_func_call
    @func_args = [:year]
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns(Date.civil(2016, 1, 15))

    @subject.call(@input, @func_id, @func_args, @func_modifier)
  end

  def test_month_arg_passed_to_func_call
    @func_args = [:month]
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @month).returns(Date.civil(2016, 1, 15))

    @subject.call(@input, @func_id, @func_args, @func_modifier)
  end

  def test_day_arg_passed_to_func_call
    @func_args = [:day]
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @day).returns(Date.civil(2016, 1, 15))

    @subject.call(@input, @func_id, @func_args, @func_modifier)
  end

  def test_date_arg_passed_to_func_call
    @func_args = [:date]
    date = Date.civil(@year, @month, @day)
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, date).returns(date)

    @subject.call(@input, @func_id, @func_args, @func_modifier)
  end

  def test_multiple_args_passed_to_func_call
    @func_args = [:month, :day]
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @month, @day).returns(Date.civil(2016, 1, 15))

    @subject.call(@input, @func_id, @func_args, @func_modifier)
  end

  def test_multiple_args_with_region_passed_to_func_call
    @func_args = [:month, :day, :region]
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @month, @day, @region).returns(Date.civil(2016, 1, 15))

    @subject.call(@input, @func_id, @func_args, @func_modifier)
  end

  def test_call_returns_error_if_target_function_returns_unknown_value
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns("bad-response")

    assert_raises Holidays::InvalidFunctionResponse do
      @subject.call(@input, @func_id, @func_args, @func_modifier)
    end
  end

  def test_call_returns_date_with_modifier
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns(Date.civil(2016, 3, 10))

    result = @subject.call(@input, @func_id, @func_args, @func_modifier)

    assert_equal(Date.civil(2016, 3, 10) + @func_modifier, result)
  end

  def test_call_returns_date_no_modifier
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns(Date.civil(2016, 3, 10))

    result = @subject.call(@input, @func_id, @func_args, nil)

    assert_equal(Date.civil(2016, 3, 10), result)
  end

  def test_call_returns_errors_when_custom_function_returns_non_date
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns("bad")

    assert_raises Holidays::InvalidFunctionResponse do
      @subject.call(@input, @func_id, @func_args, nil)
    end
  end

  def test_call_returns_error_when_custom_function_returns_mday_but_resulting_date_is_invalid
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns(32)

    assert_raises Holidays::InvalidFunctionResponse do
      @subject.call(@input, @func_id, @func_args, nil)
    end
  end

  def test_call_returns_integer_returns_modified_date
    @proc_result_cache_repo.expects(:lookup).at_most_once.with(@custom_func, @year).returns(7)

    result = @subject.call(@input, @func_id, @func_args, nil)

    assert_equal(Date.civil(2016, 1, 7), result)
  end

  def test_func_modifier_not_required
    result = @subject.call(@input, @func_id, @func_args)
    assert_equal(Date.civil(2016, 1, 15), result)
  end

  def test_validate_returns_error_if_year_not_a_number
    @input[:year] = 'bad-year'
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, @func_args)
    end
  end

  def test_validate_returns_error_if_month_not_valid
    @input[:month] = 'bad-month'
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:month])
    end

    @input[:month] = -1
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:month])
    end

    @input[:month] = 13
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:month])
    end
  end

  def test_validate_returns_error_if_day_is_not_valid
    @input[:day] = 0
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:day])
    end

    @input[:day] = 32
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:day])
    end

    @input[:day] = 'bad-day'
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:day])
    end
  end

  def test_validate_returns_error_if_region_not_a_symbol
    @input[:region] = 'blah'
    assert_raises ArgumentError do
      @subject.call(@input, @func_id, [:region])
    end
  end
end
