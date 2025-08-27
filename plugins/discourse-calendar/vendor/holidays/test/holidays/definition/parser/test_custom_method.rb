require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/parser/custom_method'
require 'holidays/definition/entity/custom_method'

class ParserCustomMethodTests < Test::Unit::TestCase
  def setup
    @validator = mock()

    @parser = Holidays::Definition::Parser::CustomMethod.new(@validator)
  end

  def test_parse_happy_single_method
    input = {"custom_method"=>{"arguments"=>"year", "ruby"=>"d = Date.civil(year, 1, 1)\nd + 2\n"}}
    @validator.expects(:valid?).with({:name => "custom_method", :arguments => "year", :source => "d = Date.civil(year, 1, 1)\nd + 2\n"}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    custom_method = result["custom_method(year)"]
    assert(custom_method)

    assert(custom_method.is_a?(Holidays::Definition::Entity::CustomMethod))
    assert_equal("custom_method", custom_method.name)
    assert_equal(["year"], custom_method.arguments)
    assert_equal("d = Date.civil(year, 1, 1)\nd + 2\n", custom_method.source)
  end

  def test_call_happy_with_multiple_methods
    input = {"custom_method"=>{"arguments"=>"year", "ruby"=>"d = Date.civil(year, 1, 1)\nd + 2\n"}, "second_method"=>{"arguments"=>"month","ruby"=>"source"}}
    @validator.expects(:valid?).with({:name => "custom_method", :arguments => "year", :source => "d = Date.civil(year, 1, 1)\nd + 2\n"}).returns(true)
    @validator.expects(:valid?).with({:name => "second_method", :arguments => "month", :source => "source"}).returns(true)

    result = @parser.call(input)

    assert_equal(2, result.size)

    custom_method = result["custom_method(year)"]
    assert(custom_method)

    assert(custom_method.is_a?(Holidays::Definition::Entity::CustomMethod))
    assert_equal("custom_method", custom_method.name)
    assert_equal(["year"], custom_method.arguments)
    assert_equal("d = Date.civil(year, 1, 1)\nd + 2\n", custom_method.source)

    second_method= result["second_method(month)"]
    assert(second_method)

    assert(second_method.is_a?(Holidays::Definition::Entity::CustomMethod))
    assert_equal("second_method", second_method.name)
    assert_equal(["month"], second_method.arguments)
    assert_equal("source", second_method.source)
  end

  def test_call_returns_empty_hash_if_methods_are_missing
    assert_equal({}, @parser.call(nil))
    assert_equal({}, @parser.call({}))
  end

  def test_call_raises_error_if_validator_returns_false_for_single_method
    input = {"custom_method"=>{"arguments"=>"year", "ruby"=>"d = Date.civil(year, 1, 1)\nd + 2\n"}}
    @validator.expects(:valid?).with({:name => "custom_method", :arguments => "year", :source => "d = Date.civil(year, 1, 1)\nd + 2\n"}).returns(false)

    assert_raises ArgumentError do
      @parser.call(input)
    end
  end

  def test_call_raises_error_if_validator_returns_false_for_one_of_multiple_methods
    input = {"custom_method"=>{"arguments"=>"year", "ruby"=>"d = Date.civil(year, 1, 1)\nd + 2\n"}, "second_method"=>{"arguments"=>"month","ruby"=>"source"}}
    @validator.expects(:valid?).with({:name => "custom_method", :arguments => "year", :source => "d = Date.civil(year, 1, 1)\nd + 2\n"}).returns(true)
    @validator.expects(:valid?).with({:name => "second_method", :arguments => "month", :source => "source"}).returns(false)

    assert_raises ArgumentError do
      @parser.call(input)
    end
  end
end
