require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/repository/cache'

class CacheRepoTests < Test::Unit::TestCase
  def setup
    @subject = Holidays::Definition::Repository::Cache.new
  end

  def test_find_supports_overlapping_holidays
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 7, 1)
    cache_data = [
      {:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day A", :regions=>[:us]},
      {:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day B", :regions=>[:us]}
    ]
    options = :us

    @subject.cache_between(start_date, end_date, cache_data, options)

    assert_equal(cache_data, @subject.find(start_date, start_date, options))
    assert_equal(cache_data, @subject.find(start_date, end_date, options))
  end

  def test_cache_returns_empty_array_no_holidays_are_found
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 7, 1)
    cache_data = [{:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day", :regions=>[:us]}]
    options = :us

    @subject.cache_between(start_date, end_date, cache_data, options)

    assert_empty(@subject.find(Date.civil(2015, 1, 2), Date.civil(2015, 1, 2), options))
    assert_empty(@subject.find(Date.civil(2015, 1, 2), Date.civil(2015, 1, 3), options))
  end

  def test_cache_returns_empty_array_when_cache_is_empty
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 7, 1)
    cache_data = []
    options = :us

    @subject.cache_between(start_date, end_date, cache_data, options)

    assert_empty(@subject.find(Date.civil(2015, 1, 2), Date.civil(2015, 1, 2), options))
    assert_empty(@subject.find(Date.civil(2015, 1, 2), Date.civil(2015, 1, 3), options))
  end

  def test_find_returns_correct_cache_data
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 7, 1)
    cache_data = [{:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day", :regions=>[:us]}]
    options = :us
    @subject.cache_between(start_date, end_date, cache_data, options)

    assert_equal(cache_data, @subject.find(start_date, start_date, options))
    assert_equal(cache_data, @subject.find(start_date, end_date, options))
  end

  def test_find_returns_nil_if_no_match_is_found
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 1)
    cache_data = [{:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day", :regions=>[:us]}]
    options = :us
    @subject.cache_between(start_date, end_date, cache_data, options)

    assert_nil(@subject.find(Date.civil(2015, 7, 1), Date.civil(2015, 12, 1), options))
    assert_nil(@subject.find(Date.civil(2015, 7, 1), Date.civil(2015, 12, 1), options))
  end

  def test_cache_between_returns_error_if_dates_are_missing
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 1)
    cache_data = [{:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day", :regions=>[:us]}]
    options = :us

    assert_raise ArgumentError do
      @subject.cache_between(nil, end_date, cache_data, options)
    end

    assert_raise ArgumentError do
      @subject.cache_between(start_date, nil, cache_data, options)
    end
  end

  def test_cache_between_returns_error_if_dates_are_invalid
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 1)
    cache_data = [{:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day", :regions=>[:us]}]
    options = :us

    assert_raise ArgumentError do
      @subject.cache_between("invalid-date", end_date, cache_data, options)
    end

    assert_raise ArgumentError do
      @subject.cache_between(start_date, "invalid-date", cache_data, options)
    end
  end

  def test_cache_between_returns_error_if_cached_data_is_not_present
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 1)
    options = :us

    assert_raise ArgumentError do
      @subject.cache_between(start_date, end_date, nil, options)
    end
  end

  def test_reset_clears_cache
    start_date = Date.civil(2015, 1, 1)
    end_date = Date.civil(2015, 1, 1)
    cache_data = [{:date=>Date.civil(2015, 1, 1), :name=>"New Year's Day", :regions=>[:us]}]
    options = :us
    @subject.cache_between(start_date, end_date, cache_data, options)

    assert_equal(cache_data, @subject.find(start_date, end_date, options))

    @subject.reset!
    assert_nil(@subject.find(start_date, end_date, options))
  end
end
