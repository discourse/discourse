require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/finder/context/between'

class BetweenTests < Test::Unit::TestCase
  def setup
    @regions = [:us]
    @observed = false
    @informal = false

    @definition_search = mock()
    @dates_driver_builder = mock()
    @options_parser = mock()

    @subject = Holidays::Finder::Context::Between.new(
      @definition_search,
      @dates_driver_builder,
      @options_parser,
    )

    @start_date = Date.civil(2015, 1, 1)
    @end_date = Date.civil(2015, 1, 1)
    @dates_driver = {2015 => [0, 1, 2], 2014 => [0, 12]}
    @options = [@regions, @observed, @informal]

    @definition_search.expects(:call).at_most_once.with(
      @dates_driver,
      @regions,
      [],
    ).returns([{
      :date => Date.civil(2015, 1, 1),
      :name => "Test",
      :regions => [:us],
    }])

    @dates_driver_builder.expects(:call).at_most_once.with(
      @start_date, @end_date,
    ).returns(
      @dates_driver,
    )

    @options_parser.expects(:call).at_most_once.with(@options).returns(@options)
  end

  def test_returns_error_if_start_date_is_missing
    assert_raise ArgumentError do
      @subject.call(nil, @end_date, @options)
    end
  end

  def test_returns_error_if_end_date_is_missing
    assert_raise ArgumentError do
      @subject.call(@start_date, nil, @options)
    end
  end

  def test_returns_single_holiday
    assert_equal(
      [
        {
          :date => Date.civil(2015, 1, 1),
          :name => "Test",
          :regions => [:us],
        }
      ],
      @subject.call(@start_date, @end_date, @options)
    )
  end

  def test_returns_sorted_multiple_holidays
    @start_date = Date.civil(2015, 1, 1)
    @end_date = Date.civil(2016, 12, 31)

    @definition_search.expects(:call).at_most_once.with(
      @dates_driver,
      @regions,
      [],
    ).returns([
      {
        :date => Date.civil(2015, 6, 1),
        :name => "2015-June",
        :regions => [:us],
      },
      {
        :date => Date.civil(2015, 1, 1),
        :name => "2015-Jan",
        :regions => [:us],
      },
      {
        :date => Date.civil(2016, 6, 1),
        :name => "2016-June",
        :regions => [:us],
      },
    ])

    @dates_driver_builder.expects(:call).at_most_once.with(
      @start_date, @end_date,
    ).returns(
      @dates_driver,
    )

    assert_equal(
      [
        {
          :date => Date.civil(2015, 1, 1),
          :name => "2015-Jan",
          :regions => [:us],
        },
        {
          :date => Date.civil(2015, 6, 1),
          :name => "2015-June",
          :regions => [:us],
        },
        {
          :date => Date.civil(2016, 6, 1),
          :name => "2016-June",
          :regions => [:us],
        },
      ],
      @subject.call(@start_date, @end_date, @options)
    )
  end

  def test_filters_holidays_returned_by_search_if_not_in_date_range
    @start_date = Date.civil(2015, 1, 1)
    @end_date = Date.civil(2015, 12, 31)

    @definition_search.expects(:call).at_most_once.with(
      @dates_driver,
      @regions,
      [],
    ).returns([
      {
        :date => Date.civil(2015, 6, 1),
        :name => "2015-June",
        :regions => [:us],
      },
      {
        :date => Date.civil(2015, 1, 1),
        :name => "2015-Jan",
        :regions => [:us],
      },
      {
        :date => Date.civil(2016, 6, 1),
        :name => "2016-June",
        :regions => [:us],
      },
    ])

    @dates_driver_builder.expects(:call).at_most_once.with(
      @start_date, @end_date,
    ).returns(
      @dates_driver,
    )

    assert_equal(
      [
        {
          :date => Date.civil(2015, 1, 1),
          :name => "2015-Jan",
          :regions => [:us],
        },
        {
          :date => Date.civil(2015, 6, 1),
          :name => "2015-June",
          :regions => [:us],
        },
      ],
      @subject.call(@start_date, @end_date, @options)
    )
  end
end
