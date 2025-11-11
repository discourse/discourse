require File.expand_path(File.dirname(__FILE__)) + '/../../test_helper'

require 'holidays/date_calculator/lunar_date.rb'

class LunarHolidaysCalculatorTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::DateCalculator::LunarDate.new
  end

  def test_korean_new_year_returns_expected_results
    assert_equal '1994-02-10', @subject.to_solar(1994,1,1, :kr).to_s
    assert_equal '1995-01-31', @subject.to_solar(1995,1,1, :kr).to_s
    assert_equal '1999-02-16', @subject.to_solar(1999,1,1, :kr).to_s
    assert_equal '2000-02-05', @subject.to_solar(2000,1,1, :kr).to_s
    assert_equal '2001-01-24', @subject.to_solar(2001,1,1, :kr).to_s
    assert_equal '2002-02-12', @subject.to_solar(2002,1,1, :kr).to_s
    assert_equal '2008-02-07', @subject.to_solar(2008,1,1, :kr).to_s
    assert_equal '2009-01-26', @subject.to_solar(2009,1,1, :kr).to_s
    assert_equal '2010-02-14', @subject.to_solar(2010,1,1, :kr).to_s
    assert_equal '2011-02-03', @subject.to_solar(2011,1,1, :kr).to_s
    assert_equal '2012-01-23', @subject.to_solar(2012,1,1, :kr).to_s
    assert_equal '2013-02-10', @subject.to_solar(2013,1,1, :kr).to_s
    assert_equal '2014-01-31', @subject.to_solar(2014,1,1, :kr).to_s
    assert_equal '2015-02-19', @subject.to_solar(2015,1,1, :kr).to_s
    assert_equal '2016-02-08', @subject.to_solar(2016,1,1, :kr).to_s
    assert_equal '2017-01-28', @subject.to_solar(2017,1,1, :kr).to_s
    assert_equal '2018-02-16', @subject.to_solar(2018,1,1, :kr).to_s
    assert_equal '2019-02-05', @subject.to_solar(2019,1,1, :kr).to_s
    assert_equal '2020-01-25', @subject.to_solar(2020,1,1, :kr).to_s
    assert_equal '2022-02-01', @subject.to_solar(2022,1,1, :kr).to_s
    assert_equal '2025-01-29', @subject.to_solar(2025,1,1, :kr).to_s
  end

  def test_buddahs_birthday_returns_expected_results
    assert_equal '1994-05-18', @subject.to_solar(1994,4,8, :kr).to_s
    assert_equal '1995-05-07', @subject.to_solar(1995,4,8, :kr).to_s
    assert_equal '1999-05-22', @subject.to_solar(1999,4,8, :kr).to_s
    assert_equal '2000-05-11', @subject.to_solar(2000,4,8, :kr).to_s
    assert_equal '2001-05-01', @subject.to_solar(2001,4,8, :kr).to_s
    assert_equal '2002-05-19', @subject.to_solar(2002,4,8, :kr).to_s
    assert_equal '2008-05-12', @subject.to_solar(2008,4,8, :kr).to_s
    assert_equal '2009-05-02', @subject.to_solar(2009,4,8, :kr).to_s
    assert_equal '2010-05-21', @subject.to_solar(2010,4,8, :kr).to_s
    assert_equal '2011-05-10', @subject.to_solar(2011,4,8, :kr).to_s
    assert_equal '2012-05-28', @subject.to_solar(2012,4,8, :kr).to_s
    assert_equal '2013-05-17', @subject.to_solar(2013,4,8, :kr).to_s
    assert_equal '2014-05-06', @subject.to_solar(2014,4,8, :kr).to_s
    assert_equal '2015-05-25', @subject.to_solar(2015,4,8, :kr).to_s
    assert_equal '2016-05-14', @subject.to_solar(2016,4,8, :kr).to_s
    assert_equal '2017-05-03', @subject.to_solar(2017,4,8, :kr).to_s
    assert_equal '2018-05-22', @subject.to_solar(2018,4,8, :kr).to_s
    assert_equal '2019-05-12', @subject.to_solar(2019,4,8, :kr).to_s
    assert_equal '2020-04-30', @subject.to_solar(2020,4,8, :kr).to_s
    assert_equal '2022-05-08', @subject.to_solar(2022,4,8, :kr).to_s
    assert_equal '2025-05-05', @subject.to_solar(2025,4,8, :kr).to_s
  end

  def test_korean_thanksgiving_returns_expected_results
    assert_equal '1994-09-20', @subject.to_solar(1994,8,15, :kr).to_s
    assert_equal '1995-09-09', @subject.to_solar(1995,8,15, :kr).to_s
    assert_equal '1999-09-24', @subject.to_solar(1999,8,15, :kr).to_s
    assert_equal '2000-09-12', @subject.to_solar(2000,8,15, :kr).to_s
    assert_equal '2001-10-01', @subject.to_solar(2001,8,15, :kr).to_s
    assert_equal '2002-09-21', @subject.to_solar(2002,8,15, :kr).to_s
    assert_equal '2008-09-14', @subject.to_solar(2008,8,15, :kr).to_s
    assert_equal '2009-10-03', @subject.to_solar(2009,8,15, :kr).to_s
    assert_equal '2010-09-22', @subject.to_solar(2010,8,15, :kr).to_s
    assert_equal '2011-09-12', @subject.to_solar(2011,8,15, :kr).to_s
    assert_equal '2012-09-30', @subject.to_solar(2012,8,15, :kr).to_s
    assert_equal '2013-09-19', @subject.to_solar(2013,8,15, :kr).to_s
    assert_equal '2014-09-08', @subject.to_solar(2014,8,15, :kr).to_s
    assert_equal '2015-09-27', @subject.to_solar(2015,8,15, :kr).to_s
    assert_equal '2016-09-15', @subject.to_solar(2016,8,15, :kr).to_s
    assert_equal '2017-10-04', @subject.to_solar(2017,8,15, :kr).to_s
    assert_equal '2018-09-24', @subject.to_solar(2018,8,15, :kr).to_s
    assert_equal '2019-09-13', @subject.to_solar(2019,8,15, :kr).to_s
    assert_equal '2020-10-01', @subject.to_solar(2020,8,15, :kr).to_s
    assert_equal '2022-09-10', @subject.to_solar(2022,8,15, :kr).to_s
    assert_equal '2025-10-06', @subject.to_solar(2025,8,15, :kr).to_s
  end

  def test_hung_kings_festival_returns_expected_results
    assert_equal '2014-04-09', @subject.to_solar(2014,3,10, :vi).to_s
    assert_equal '2015-04-28', @subject.to_solar(2015,3,10, :vi).to_s
    assert_equal '2016-04-16', @subject.to_solar(2016,3,10, :vi).to_s
    assert_equal '2017-04-06', @subject.to_solar(2017,3,10, :vi).to_s
    assert_equal '2018-03-27', @subject.to_solar(2018,3,10, :vi).to_s
  end
end
