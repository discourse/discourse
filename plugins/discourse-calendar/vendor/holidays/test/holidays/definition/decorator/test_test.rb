# Heh at this file name
require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/decorator/test'
require 'holidays/definition/entity/test'

class DecoratorTestTests < Test::Unit::TestCase
  def setup
    @decorator = Holidays::Definition::Decorator::Test.new
  end

  def test_call_generates_source_from_entity_single_date
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01')],
      :regions => [:us],
      :name => 'Test Holiday',
      :holiday? => true,
    )

    source = @decorator.call(entity)
    expected_source = "assert_equal \"Test Holiday\", (Holidays.on(Date.civil(2016, 1, 1), [:us])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_multiple_dates
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01'), DateTime.parse('2017-01-01')],
      :regions => [:us],
      :name => 'Test Holiday',
      :holiday? => true
    )

    source = @decorator.call(entity)
    expected_source = "assert_equal \"Test Holiday\", (Holidays.on(Date.civil(2016, 1, 1), [:us])[0] || {})[:name]\nassert_equal \"Test Holiday\", (Holidays.on(Date.civil(2017, 1, 1), [:us])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_single_date_with_options
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01')],
      :regions => [:us],
      :options => ['option1'],
      :name => 'Test Holiday',
      :holiday? => true,
    )

    source = @decorator.call(entity)
    expected_source = "assert_equal \"Test Holiday\", (Holidays.on(Date.civil(2016, 1, 1), [:us], [:option1])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_single_date_with_holiday_flag
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01')],
      :regions => [:us],
      :holiday? => false,
    )

    source = @decorator.call(entity)
    expected_source = "assert_nil (Holidays.on(Date.civil(2016, 1, 1), [:us])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_single_date_multiple_regions
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01')],
      :regions => [:us, :us_ca, :ca],
      :name => 'Test Holiday',
      :holiday? => true,
    )

    source = @decorator.call(entity)
    expected_source = "assert_equal \"Test Holiday\", (Holidays.on(Date.civil(2016, 1, 1), [:us, :us_ca, :ca])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_multiple_dates_multiple_regions
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01'), DateTime.parse('2017-01-01')],
      :regions => [:us, :us_ca, :ca],
      :name => 'Test Holiday',
      :holiday? => true,
    )

    source = @decorator.call(entity)
    expected_source = "assert_equal \"Test Holiday\", (Holidays.on(Date.civil(2016, 1, 1), [:us, :us_ca, :ca])[0] || {})[:name]\nassert_equal \"Test Holiday\", (Holidays.on(Date.civil(2017, 1, 1), [:us, :us_ca, :ca])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_multiple_dates_multiple_regions_holiday_flag_false
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01'), DateTime.parse('2017-01-01')],
      :regions => [:us, :us_ca, :ca],
      :name => 'Test Holiday',
      :holiday? => false,
    )

    source = @decorator.call(entity)
    expected_source = "assert_nil (Holidays.on(Date.civil(2016, 1, 1), [:us, :us_ca, :ca])[0] || {})[:name]\nassert_nil (Holidays.on(Date.civil(2017, 1, 1), [:us, :us_ca, :ca])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_single_date_multiple_regions_holiday_flag_false
    entity = Holidays::Definition::Entity::Test.new(
      :dates => [DateTime.parse('2016-01-01')],
      :regions => [:us, :us_ca, :ca],
      :name => 'Test Holiday',
      :holiday? => false,
    )

    source = @decorator.call(entity)
    expected_source = "assert_nil (Holidays.on(Date.civil(2016, 1, 1), [:us, :us_ca, :ca])[0] || {})[:name]\n"

    assert_equal expected_source, source
  end
end
