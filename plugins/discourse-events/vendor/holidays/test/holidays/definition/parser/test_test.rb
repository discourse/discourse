# Heh at this file name
require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/parser/test'
require 'holidays/definition/entity/test'

class ParserTestTests < Test::Unit::TestCase
  def setup
    @validator = mock()

    @parser = Holidays::Definition::Parser::Test.new(@validator)
  end

  def test_parse_no_tests
    input = nil
    result = @parser.call(input)

    assert_equal(0, result.size)
  end

  def test_parse_single_test_happy
    input = [ { "given" => { "date" => "2016-01-01", "regions" => ['us'] }, "expect" => { "name" => "Test Holiday" } } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01"], :regions=> ['us'], :options => nil, :name => "Test Holiday", :holiday => nil}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    test = result.first
    assert(test)

    assert(test.is_a?(Holidays::Definition::Entity::Test))
    assert_equal([DateTime.parse('2016-01-01')], test.dates)
    assert_equal([:us], test.regions)
    assert_equal("Test Holiday", test.name)
    assert(test.holiday?)
  end

  def test_parse_single_test_with_options
    input = [ { "given" => { "date" => "2016-01-01", "regions" => ['us'], "options" => ['option1']}, "expect" => { "name" => "Test Holiday" } } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01"], :regions=> ['us'], :name => "Test Holiday", :options => ['option1'], :holiday => nil}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    test = result.first
    assert(test)

    assert(test.is_a?(Holidays::Definition::Entity::Test))
    assert_equal([DateTime.parse('2016-01-01')], test.dates)
    assert_equal([:us], test.regions)
    assert_equal([:option1], test.options)
    assert_equal("Test Holiday", test.name)
    assert(test.holiday?)
  end

  def test_parse_single_test_with_single_option_as_string
    input = [ { "given" => { "date" => "2016-01-01", "regions" => ['us'], "options" => 'option1'}, "expect" => { "name" => "Test Holiday" } } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01"], :regions=> ['us'], :name => "Test Holiday", :options => 'option1', :holiday => nil}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    test = result.first
    assert(test)

    assert(test.is_a?(Holidays::Definition::Entity::Test))
    assert_equal([DateTime.parse('2016-01-01')], test.dates)
    assert_equal([:us], test.regions)
    assert_equal([:option1], test.options)
    assert_equal("Test Holiday", test.name)
    assert(test.holiday?)
  end

  def test_parse_single_test_no_name_no_holiday
    input = [ { "given" => { "date" => "2016-01-01", "regions" => ['us']}, "expect" => { "holiday" => false } } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01"], :regions=> ['us'], :name => nil, :options => nil, :holiday => false}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    test = result.first
    assert(test)

    assert(test.is_a?(Holidays::Definition::Entity::Test))
    assert_equal([DateTime.parse('2016-01-01')], test.dates)
    assert_equal([:us], test.regions)
    assert_nil(test.options)
    assert_nil(test.name)
    assert_equal(false, test.holiday?)
  end

  def test_parse_single_test_with_options_no_name_no_holiday
    input = [ { "given" => { "date" => "2016-01-01", "regions" => ['us'], "options" => ['option1']}, "expect" => { "holiday" => false } } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01"], :regions=> ['us'], :name => nil, :options => ['option1'], :holiday => false}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    test = result.first
    assert(test)

    assert(test.is_a?(Holidays::Definition::Entity::Test))
    assert_equal([DateTime.parse('2016-01-01')], test.dates)
    assert_equal([:us], test.regions)
    assert_equal([:option1], test.options)
    assert_nil(test.name)
    assert_equal(false, test.holiday?)
  end

  def test_parse_single_test_multiple_dates
    input = [ { "given" => { "date" => ["2016-01-01", "2017-01-01"], "regions" => ['us']}, "expect" => { "name" => "Test Holiday"} } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01", "2017-01-01"], :regions=> ['us'], :name => "Test Holiday", :options => nil, :holiday => nil}).returns(true)

    result = @parser.call(input)

    assert_equal(1, result.size)

    test = result.first
    assert(test)

    assert(test.is_a?(Holidays::Definition::Entity::Test))
    assert_equal([DateTime.parse('2016-01-01'), DateTime.parse('2017-01-01')], test.dates)
    assert_equal([:us], test.regions)
    assert_nil(test.options)
    assert_equal("Test Holiday", test.name)
    assert(test.holiday?)
  end

  def test_parse_single_test_fail_validation
    input = [ { "given" => { "date" => "2016-01-01", "regions" => ['us']}, "expect" => { "name" => "Test Holiday"} } ]
    @validator.expects(:valid?).with({:dates => ["2016-01-01"], :regions=> ['us'], :name => "Test Holiday", :options => nil, :holiday => nil}).returns(false)

    assert_raises ArgumentError do
      @parser.call(input)
    end
  end
end
