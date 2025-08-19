require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/validator/custom_method'

class CustomMethodValidatorTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::Definition::Validator::CustomMethod.new
  end

  def test_valid_returns_true_if_valid
    m = {:name => "good_method", :arguments => "year", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_with_multiple_arguments
    m = {:name => "good_method", :arguments => "year,month", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_with_date_argument
    m = {:name => "good_method", :arguments => "date", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_with_year_argument
    m = {:name => "good_method", :arguments => "year", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_with_month_argument
    m = {:name => "good_method", :arguments => "month", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_with_day_argument
    m = {:name => "good_method", :arguments => "day", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_with_region_argument
    m = {:name => "good_method", :arguments => "region", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_true_multiple_arguments_with_whitespace
    m = {:name => "good_method", :arguments => "year        ,          month", :source => "source"}
    assert @subject.valid?(m)
  end

  def test_valid_returns_false_if_single_argument_contain_carriage_return
    m = {:name => "bad_method", :arguments =>"year\n", :source =>"d = Date.civil(year, 1, 1)\nd + 2\n"}
    assert_false @subject.valid?(m)
  end

  def test_valid_returns_false_if_multiple_arguments_contain_carriage_return
    m = {:name => "bad_method", :arguments =>"year,month\n", :source =>"d = Date.civil(year, 1, 1)\nd + 2\n"}
    assert_false @subject.valid?(m)
  end

  def test_valid_returns_false_if_multiple_arguments_contain_carriage_return_with_whitespace
    m = {:name => "bad_method", :arguments =>"year          ,         month\n", :source =>"d = Date.civil(year, 1, 1)\nd + 2\n"}
    assert_false @subject.valid?(m)
  end

  def test_valid_returns_false_if_no_source
    m = {:name => "bad_method", :arguments => "day"}
    assert_false @subject.valid?(m)
  end

  def test_valid_returns_false_if_source_is_empty
    m = {:name => "bad_method", :arguments => "day", :source => ""}
    assert_false @subject.valid?(m)
  end

  def test_valid_returns_false_if_name_is_missing
    m = {:arguments => "day", :source => "source"}
    assert_false @subject.valid?(m)
  end

  def test_valid_returns_false_if_name_is_empty
    m = {:name => "", :arguments => "day", :source => "source"}
    assert_false @subject.valid?(m)
  end

  def test_returns_false_if_multiple_arguments_contain_unrecognized_value
    m = {:name => "bad_method", :arguments => "year,month,day,date,unknown", :source => "source"}
    assert_false @subject.valid?(m)
  end

  def test_returns_false_if_single_argument_contains_unrecognized_value
    m = {:name => "bad_method", :arguments => "unknown", :source => "source"}
    assert_false @subject.valid?(m)
  end
end
