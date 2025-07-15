require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/finder/context/next_holiday'

class NextHolidayTests < Test::Unit::TestCase
  def setup
    @regions = [:us]
    @observed = false
    @informal = false

    @definition_search = mock()
    @dates_driver_builder = mock()
    @options_parser = mock()

    @subject = Holidays::Finder::Context::NextHoliday.new(
      @definition_search,
      @dates_driver_builder,
      @options_parser,
    )

    @holiday_count = 1
    @from_date= Date.civil(2015, 1, 1)
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
      @from_date, @from_date >> 12,
    ).returns(
      @dates_driver,
    )

    @options_parser.expects(:call).at_most_once.with(@options).returns(@options)
  end

  def test_returns_error_if_holidays_count_is_missing
    assert_raise ArgumentError do
      @subject.call(nil, @from_date, @options)
    end
  end

  def test_returns_error_if_holidays_count_is_less_than_or_equal_to_zero
    assert_raise ArgumentError do
      @subject.call(0, @from_date, @options)
    end
  end

  def test_returns_error_if_from_date_is_missing
    assert_raise ArgumentError do
      @subject.call(@holiday_count, nil, @options)
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
      @subject.call(@holiday_count, @from_date, @options)
    )
  end

  def test_returns_correct_holidays_based_on_holiday_count
    @definition_search.expects(:call).at_most_once.with(
      @dates_driver,
      @regions,
      [],
    ).returns([
      {
        :date => Date.civil(2015, 1, 1),
        :name => "Test",
        :regions => [:us],
      },
      {
        :date => Date.civil(2015, 2, 1),
        :name => "Test",
        :regions => [:us],
      },
      {
        :date => Date.civil(2015, 12, 1),
        :name => "Test",
        :regions => [:us],
      },
      ])

      assert_equal(
        [
          {
            :date => Date.civil(2015, 1, 1),
            :name => "Test",
            :regions => [:us],
          },
          {
            :date => Date.civil(2015, 2, 1),
            :name => "Test",
            :regions => [:us],
          }
        ],
          @subject.call(2, @from_date, @options)
      )
  end

  def test_returns_correctly_sorted_holidays_based_on_holiday_count_if_holidays_are_out_of_order
    @definition_search.expects(:call).at_most_once.with(
      @dates_driver,
      @regions,
      [],
    ).returns([
      {
        :date => Date.civil(2015, 1, 1),
        :name => "Test",
        :regions => [:us],
      },
      {
        :date => Date.civil(2015, 12, 1),
        :name => "Test",
        :regions => [:us],
      },
      {
        :date => Date.civil(2015, 2, 1),
        :name => "Test",
        :regions => [:us],
      },
      ]
    )

    assert_equal(
      [
        {
          :date => Date.civil(2015, 1, 1),
          :name => "Test",
          :regions => [:us],
        },
        {
          :date => Date.civil(2015, 2, 1),
          :name => "Test",
          :regions => [:us],
        }
      ],
        @subject.call(2, @from_date, @options)
    )
  end
end
