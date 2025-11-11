# Heh at this file name
require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/validator/test'

class TestValidatorTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::Definition::Validator::Test.new
  end

  def test_returns_true_if_valid
    t = {:dates => ['2016-01-01'], :regions => ['us'], :name => 'test', holiday: true, :options => ['option1']}
    assert @subject.valid?(t)
  end

  def test_returns_false_if_missing_dates
    t = {:regions => ['us'], :name => 'test'}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_false_if_dates_contains_invalid_value
    t = {:dates => ['2016-01-01', 'invalid-date'], :regions => ['us'], :name => 'test'}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_false_if_missing_regions
    t = {:dates => ['2016-01-01'], :name => 'test'}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_false_if_regions_contains_non_string
    t = {:dates => ['2016-01-01'], :regions => [3], :name => 'test'}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_false_if_name_not_a_string
    t = {:dates => ['2016-01-01'], :regions => ['us'], :name => 3}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_false_if_holiday_not_a_boolean
    t = {:dates => ['2016-01-01'], :regions => ['us'], :name => 'Test', :holiday => 'invalid'}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_true_if_options_not_array_but_is_string
    t = {:dates => ['2016-01-01'], :regions => ['us'], :name => 'test', :options => 'option1'}
    assert @subject.valid?(t)
  end

  def test_returns_false_if_options_contains_non_string
    t = {:dates => ['2016-01-01'], :regions => ['us'], :name => 'Test', :options => [3]}
    assert_equal false, @subject.valid?(t)
  end

  def test_returns_false_if_both_holiday_and_name_are_missing
    t = {:dates => ['2016-01-01'], :regions => ['us']}
    assert_equal false, @subject.valid?(t)
  end
end
