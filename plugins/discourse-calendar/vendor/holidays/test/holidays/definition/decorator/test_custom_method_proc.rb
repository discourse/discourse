require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/decorator/custom_method_proc'
require 'holidays/definition/entity/custom_method'

class DecoratorCustomMethodProcTests < Test::Unit::TestCase
  def setup
    @decorator = Holidays::Definition::Decorator::CustomMethodProc.new
  end

  def test_generates_lambda_from_entity
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year"],
      source: "Date.civil(year, 1, 1)"
    )

    proc = @decorator.call(entity)
    expected_proc = Proc.new { |year| eval("Date.civil(year, 1, 1)") }

    assert_equal expected_proc.call(2015), proc.call(2015)
  end

  def test_generates_lamba_from_entity_with_multiple_lines
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year"],
      source: "d = Date.civil(year, 1, 1)\nd + 2"
    )

    proc = @decorator.call(entity)
    expected_proc = Proc.new { |year| eval("d = Date.civil(year, 1, 1)\nd + 2") }

    assert_equal expected_proc.call(2015), proc.call(2015)
  end

  def test_generates_lamba_from_entity_with_multiple_arguments
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year", "month"],
      source: "Date.civil(year, month, 1)"
    )

    proc = @decorator.call(entity)
    expected_proc = Proc.new { |year, month| eval("Date.civil(year, month, 1)") }

    assert_equal expected_proc.call(2015, 6), proc.call(2015, 6)
  end

  def test_generate_returns_error_if_missing_name
    entity = Holidays::Definition::Entity::CustomMethod.new(
      arguments: ["year", "month"],
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end

    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "",
      arguments: ["year", "month"],
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end

  def test_generate_returns_error_if_arguments_is_missing
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end

    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: [],
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end


  def test_generate_returns_error_if_source_is_missing
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year"],
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end

    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year"],
      source: "",
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end
end
