require File.expand_path(File.dirname(__FILE__)) + '/../test_helper'

class AnyHolidaysDuringWorkWeekTests < Test::Unit::TestCase
  def subject
    Holidays.method(:any_holidays_during_work_week?)
  end

  def test_returns_true_when_single_holiday_exists_during_week
    assert subject.call(Date.new(2018, 1, 1), :us)
  end

  def test_returns_true_when_multiple_holidays_exist_during_week
    assert subject.call(Date.new(2018, 12, 26), :gb)
  end

  def test_returns_true_if_informal_flag_set_and_informal_holiday_exists_during_week
    assert subject.call(Date.new(2018, 10, 31), :us, :informal)
  end

  def test_returns_true_when_no_region_specified_and_single_holiday_exists_during_week
    assert subject.call(Date.new(2018, 1, 1))
  end

  def test_returns_true_if_both_informal_and_observed_flags_set_and_informal_holiday_observed_during_week
    assert subject.call(Date.new(2008, 11, 30), :gb_sct, :informal, :observed)
  end

  def test_returns_true_when_observed_flag_set_and_holiday_is_observed_during_week
    assert subject.call(Date.new(2012,9,5), :us, :observed)
  end

  def test_returns_true_when_observed_flag_set_and_holiday_is_observed_on_monday
    assert subject.call(Date.new(2018,11,12), :us, :observed)
  end

  def test_returns_true_with_multiple_regions_and_holiday_occurs_during_week
    assert subject.call(Date.new(2018,1,1), [:us, :gb])
  end

  def test_returns_true_when_observed_flag_set_and_holiday_on_saturday_but_observed_on_friday
    assert subject.call(Date.new(2018,7,3), [:us], :observed)
  end

  def test_returns_false_when_no_holiday_exists_during_week
    assert_equal false, subject.call(Date.new(2018,7,30), :us)
  end

  def test_returns_false_when_holiday_on_sunday
    assert_equal false, subject.call(Date.new(2018,11,11), :us)
  end

  def test_returns_false_when_holiday_on_saturday
    assert_equal false, subject.call(Date.new(2017,11,11), :us)
  end

  def test_returns_false_when_observed_flag_not_set_and_holiday_occurs_on_sunday_but_observed_on_monday
    assert_equal false, subject.call(Date.new(2017,1,1), :us)
  end

  def test_returns_false_if_informal_and_observed_flags_both_set_and_no_holiday_exists_during_week
    assert_equal false, subject.call(Date.new(2018,7,30), :us, :informal, :observed)
  end

  def test_returns_false_when_informal_flag_set_and_informal_holiday_occurs_on_weekend
    assert_equal false, subject.call(Date.new(2018,4,14), :us, :informal)
  end

  def test_returns_false_when_informal_flag_set_but_observed_is_not_and_informal_holiday_is_observed_on_monday
    assert_equal false, subject.call(Date.new(2008, 11, 30), :gb_sct, :informal)
  end

  def test_verify_count_of_weeks_without_any_holidays_for_2012
    weeks_in_2012 = Date.commercial(2013, -1).cweek
    holidays_in_2012 = weeks_in_2012.times.count { |week| subject.call(Date.commercial(2012,week+1), :us) == false }
    assert_equal 45, holidays_in_2012
  end

  def test_returns_true_for_new_years_in_any_region
    assert subject.call(Date.civil(2016, 1, 1))
  end

  # These are in response to https://github.com/holidays/holidays/issues/264, just to be completely sure it's fixed.
  def returns_true_for_various_holidays_in_poland
    assert subject.call(Date.civil(2018, 1, 1), :pl)
    assert subject.call(Date.civil(2018, 1, 2), :pl)
    assert subject.call(Date.civil(2018, 5, 2), :pl)
    assert subject.call(Date.civil(2018, 5, 3), :pl)
    assert subject.call(Date.today, Date.today + 365*2, :pl, :observed)
  end
end
