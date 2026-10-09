require File.expand_path(File.dirname(__FILE__)) + '/../../test_helper'

require 'holidays/date_calculator/easter'

class GregorianEasterDateCalculatorTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::DateCalculator::Easter::Gregorian.new
  end

  def test_calculate_easter_for_returns_expected_results
    assert_equal '0960-04-20', @subject.calculate_easter_for(960).to_s
    assert_equal '1800-04-13', @subject.calculate_easter_for(1800).to_s
    assert_equal '1899-04-02', @subject.calculate_easter_for(1899).to_s
    assert_equal '1900-04-15', @subject.calculate_easter_for(1900).to_s
    assert_equal '1999-04-04', @subject.calculate_easter_for(1999).to_s
    assert_equal '2000-04-23', @subject.calculate_easter_for(2000).to_s
    assert_equal '2025-04-20', @subject.calculate_easter_for(2025).to_s
    assert_equal '2035-03-25', @subject.calculate_easter_for(2035).to_s
    assert_equal '2067-04-03', @subject.calculate_easter_for(2067).to_s
    assert_equal '2099-04-12', @subject.calculate_easter_for(2099).to_s
  end

  def test_calculate_orthodox_easter_for_returns_expects_results
    assert_equal '2000-04-30', @subject.calculate_orthodox_easter_for(2000).to_s
    assert_equal '2008-04-27', @subject.calculate_orthodox_easter_for(2008).to_s
    assert_equal '2009-04-19', @subject.calculate_orthodox_easter_for(2009).to_s
    assert_equal '2011-04-24', @subject.calculate_orthodox_easter_for(2011).to_s
    assert_equal '2020-04-19', @subject.calculate_orthodox_easter_for(2020).to_s
  end
end
