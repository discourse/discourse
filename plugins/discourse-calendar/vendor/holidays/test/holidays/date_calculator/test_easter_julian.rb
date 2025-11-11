require File.expand_path(File.dirname(__FILE__)) + '/../../test_helper'

require 'holidays/date_calculator/easter'

class JulianEasterDateCalculatorTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::DateCalculator::Easter::Julian.new
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
    assert_equal '0960-04-22', @subject.calculate_orthodox_easter_for(960).to_s
    assert_equal '1500-04-19', @subject.calculate_orthodox_easter_for(1500).to_s
    assert_equal '2000-04-17', @subject.calculate_orthodox_easter_for(2000).to_s
    assert_equal '2001-04-02', @subject.calculate_orthodox_easter_for(2001).to_s
    assert_equal '2015-03-30', @subject.calculate_orthodox_easter_for(2015).to_s
    assert_equal '2016-04-18', @subject.calculate_orthodox_easter_for(2016).to_s
    assert_equal '2017-04-03', @subject.calculate_orthodox_easter_for(2017).to_s
    assert_equal '2020-04-06', @subject.calculate_orthodox_easter_for(2020).to_s
    assert_equal '2050-04-04', @subject.calculate_orthodox_easter_for(2050).to_s
    assert_equal '2100-04-18', @subject.calculate_orthodox_easter_for(2100).to_s
    assert_equal '2500-04-08', @subject.calculate_orthodox_easter_for(2500).to_s
  end
end
