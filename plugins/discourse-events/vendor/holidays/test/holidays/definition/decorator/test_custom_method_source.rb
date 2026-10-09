require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/decorator/custom_method_source'
require 'holidays/definition/entity/custom_method'

class DecoratorCustomMethodSourceTests < Test::Unit::TestCase
  def setup
    @decorator = Holidays::Definition::Decorator::CustomMethodSource.new
  end

  def test_call_generates_source_from_entity
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year"],
      source: "Date.civil(year, 1, 1)"
    )

    source = @decorator.call(entity)
    expected_source = "\"#{entity.name}(#{entity.arguments[0]})\" => Proc.new { |year|\n#{entity.source}}"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_with_multiple_arguments
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year", "month"],
      source: "Date.civil(year, month, 1)"
    )

    source = @decorator.call(entity)
    expected_args = "#{entity.arguments[0]}, #{entity.arguments[1]}"

    expected_source = "\"#{entity.name}(#{expected_args})\" => Proc.new { |#{expected_args}|\n#{entity.source}}"

    assert_equal expected_source, source
  end

  def test_call_generates_source_from_entity_when_source_is_multiple_lines
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year"],
      source: "d = Date.civil(year, 1, 1)\nd + 2"
    )

    source = @decorator.call(entity)
    expected_source = "\"#{entity.name}(#{entity.arguments[0]})\" => Proc.new { |year|\n#{entity.source}}"

    assert_equal expected_source, source
  end

  def test_call_raises_error_if_missing_name
    entity = Holidays::Definition::Entity::CustomMethod.new(
      arguments: ["year", "month"],
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end

  def test_call_raises_error_if_missing_arguments
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end

  def test_call_raises_error_if_arguments_is_not_an_array
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: "test",
      source: "Date.civil(year, month, 1)"
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end

  def test_call_raises_error_if_missing_source
    entity = Holidays::Definition::Entity::CustomMethod.new(
      name: "test",
      arguments: ["year", "month"],
    )

    assert_raises ArgumentError do
      @decorator.call(entity)
    end
  end
end
