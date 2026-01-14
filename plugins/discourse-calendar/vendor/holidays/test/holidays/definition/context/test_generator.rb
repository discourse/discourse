require File.expand_path(File.dirname(__FILE__)) + '/../../../test_helper'

require 'holidays/definition/context/generator'

class GeneratorTests < Test::Unit::TestCase
  def setup
    @custom_method_parser = mock()
    @custom_method_source_decorator = mock()
    @custom_methods_repository = mock()

    @parsed_custom_method = Holidays::Definition::Entity::CustomMethod.new(
      name: 'custom_method',
      arguments: [:year, :month],
      source: "some source",
    )

    @test_parser = mock()
    @test_source_generator = mock()

    @module_source_generator = mock()

    @generator = Holidays::Definition::Context::Generator.new(
      @custom_method_parser,
      @custom_method_source_decorator,
      @custom_methods_repository,
      @test_parser,
      @test_source_generator,
      @module_source_generator,
    )
  end

  def test_parse_definition_files_raises_error_if_argument_is_nil
    assert_raises ArgumentError do
      @generator.parse_definition_files(nil)
    end
  end

  def test_parse_definition_files_raises_error_if_files_are_empty
    assert_raises ArgumentError do
      @generator.parse_definition_files([])
    end
  end

  def test_parse_definition_files_correctly_parse_regions
    files = ['test/data/test_single_custom_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}]).returns(['parsed tests'])

    regions = @generator.parse_definition_files(files)[0]

    assert_equal [:custom_single_file], regions
  end

  def test_parse_definitions_files_correctly_parse_rules_by_month
    files = ['test/data/test_single_custom_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}]).returns(['parsed tests'])

    rules_by_month = @generator.parse_definition_files(files)[1]

    expected_rules_by_month = {
      6 => [
        {
          :mday    => 20,
          :name    => "Company Founding",
          :regions => [:custom_single_file]
        }
      ]
    }

    assert_equal expected_rules_by_month, rules_by_month
  end

  def test_parse_definition_files_correctly_parse_custom_methods
    files = ['test/data/test_single_custom_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}]).returns(['parsed tests'])

    custom_methods = @generator.parse_definition_files(files)[2]

    expected_custom_methods = {}
    assert_equal expected_custom_methods, custom_methods
  end

  def test_parse_definition_files_correctly_parse_tests
    files = ['test/data/test_single_custom_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}]).returns(['parsed tests'])

    parsed_tests = @generator.parse_definition_files(files)[3]

    assert_equal ["parsed tests"], parsed_tests
  end

  def test_generate_definition_source_correctly_generate_module_src
    files = ['test/data/test_single_custom_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}]).returns(['parsed tests'])

    @module_source_generator.expects(:call).with("test", ["test/data/test_single_custom_holiday_defs.yaml"], [:custom_single_file], ["      6 => [{:mday => 20, :name => \"Company Founding\", :regions => [:custom_single_file]}]"], "").returns("module source")
    @test_source_generator.expects(:call).with('test', ['test/data/test_single_custom_holiday_defs.yaml'], ['parsed tests']).returns("test source")

    regions, rules_by_month, custom_methods, tests = @generator.parse_definition_files(files)
    module_src = @generator.generate_definition_source("test", files, regions, rules_by_month, custom_methods, tests)[0]

    expected_module_src = "module source"

    assert_equal expected_module_src, module_src
  end

  def test_generate_definition_source_correctly_generate_test_src
    files = ['test/data/test_single_custom_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}]).returns(['parsed tests'])

    @module_source_generator.expects(:call).returns("module_source")

    @test_source_generator.expects(:call).with('test', ['test/data/test_single_custom_holiday_defs.yaml'], ['parsed tests']).returns("test source")

    regions, rules_by_month, custom_methods, tests = @generator.parse_definition_files(files)
    test_src = @generator.generate_definition_source("test", files, regions, rules_by_month, custom_methods, tests)[1]

    assert_equal 'test source', test_src
  end

  def test_parse_definitions_files_correctly_parse_year_range_by_month
    files = ['test/data/test_custom_year_range_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2017-01-01', 'regions' => ['custom_year_range_file']}, 'expect' => {'name' => 'after_year'}}]).returns(['parsed tests'])

    rules_by_month = @generator.parse_definition_files(files)[1]

    expected_rules_by_month = {
      6 => [
        {
          :name => "after_year",
          :regions => [:custom_year_range_file],
          :mday => 1,
          :year_ranges => {:from => 2016}
        },
        {
          :name => "before_year",
          :regions => [:custom_year_range_file],
          :mday => 2,
          :year_ranges => {:until => 2017}
        },
        {
          :name => "between_year",
          :regions => [:custom_year_range_file],
          :mday => 3,
          :year_ranges => {:between => 2016..2018 }
        },
        {
          :name => "limited_year",
          :regions => [:custom_year_range_file],
          :mday => 4,
          :year_ranges => {:limited => [2016,2018,2019]}
        }
      ]
    }

    assert_equal expected_rules_by_month, rules_by_month
  end

  def test_generate_definition_source_correctly_generate_yearrange_test_src
    files = ['test/data/test_custom_year_range_holiday_defs.yaml']
    @custom_method_parser.expects(:call).with(nil).returns({})

    @test_parser.expects(:call).with([{'given' => {'date' => '2017-01-01', 'regions' => ['custom_year_range_file']}, 'expect' => {'name' => 'after_year'}}]).returns(['parsed tests'])

    @test_source_generator.expects(:call).with('test', ['test/data/test_custom_year_range_holiday_defs.yaml'], ['parsed tests']).returns('test source')

    @module_source_generator.expects(:call).with("test", ["test/data/test_custom_year_range_holiday_defs.yaml"], [:custom_year_range_file], ["      6 => [{:mday => 1, :year_ranges => { :from => 2016 },:name => \"after_year\", :regions => [:custom_year_range_file]},\n            {:mday => 2, :year_ranges => { :until => 2017 },:name => \"before_year\", :regions => [:custom_year_range_file]},\n            {:mday => 3, :year_ranges => { :between => 2016..2018 },:name => \"between_year\", :regions => [:custom_year_range_file]},\n            {:mday => 4, :year_ranges => { :limited => [2016, 2018, 2019] },:name => \"limited_year\", :regions => [:custom_year_range_file]}]"], "").returns('module_source')

    regions, rules_by_month, custom_methods, tests = @generator.parse_definition_files(files)
    module_src = @generator.generate_definition_source("test", files, regions, rules_by_month, custom_methods, tests)[0]
    expected_module_src = "module_source"

    assert_equal expected_module_src, module_src
  end

  def test_generate_definition_source_correctly_generate_module_src_with_custom_methods
    files = ['test/data/test_single_custom_holiday_with_custom_procs.yaml']

    @custom_method_parser.expects(:call).with('custom_method' => {'arguments' => 'year, month', 'source' => "d = Date.civil(year, month, 1)\nd + 2\n"}).returns({"custom_method(year, month)" => @parsed_custom_method})
    @custom_methods_repository.expects(:find).twice.with('custom_method(year, month)').returns(nil)
    @custom_method_source_decorator.expects(:call).once.with(@parsed_custom_method).returns("\"custom_method(year, month)\" => Proc.new { |year, month|\nsource_stuff\n}")

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}, {'given' => {'date' => '2015-01-01', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Custom Holiday'}}]).returns(['parsed tests'])

    @module_source_generator.expects(:call).with("test", ["test/data/test_single_custom_holiday_with_custom_procs.yaml"], [:custom_single_file], ["      0 => [{:function => \"custom_method(year, month)\", :function_arguments => [:year, :month], :function_modifier => 5, :name => \"Custom Holiday\", :regions => [:custom_single_file]}]", "      6 => [{:mday => 20, :name => \"Company Founding\", :regions => [:custom_single_file]}]"], "\"custom_method(year, month)\" => Proc.new { |year, month|\nsource_stuff\n},\n\n").returns("module source")
    @test_source_generator.expects(:call).with('test', ['test/data/test_single_custom_holiday_with_custom_procs.yaml'], ['parsed tests']).returns('test source')

    regions, rules_by_month, custom_methods, tests = @generator.parse_definition_files(files)
    module_src = @generator.generate_definition_source("test", files, regions, rules_by_month, custom_methods, tests)[0]

    expected_module_src = "module source"

    assert_equal expected_module_src, module_src
  end

  def test_generate_definition_source_correctly_generate_test_src_with_custom_methods
    files = ['test/data/test_single_custom_holiday_with_custom_procs.yaml']

    @custom_method_parser.expects(:call).with('custom_method' => {'arguments' => 'year, month', 'source' => "d = Date.civil(year, month, 1)\nd + 2\n"}).returns({"custom_method(year, month)" => @parsed_custom_method})
    @custom_methods_repository.expects(:find).twice.with('custom_method(year, month)').returns(nil)
    @custom_method_source_decorator.expects(:call).once.with(@parsed_custom_method).returns("\"custom_method(year, month)\" => Proc.new { |year, month|\nsource_stuff\n}")

    @test_parser.expects(:call).with([{'given' => {'date' => '2013-06-20', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Company Founding'}}, {'given' => {'date' => '2015-01-01', 'regions' => ['custom_single_file']}, 'expect' => {'name' => 'Custom Holiday'}}]).returns(['parsed tests'])

    @module_source_generator.expects(:call).returns("module_source")
    @test_source_generator.expects(:call).with('test', ['test/data/test_single_custom_holiday_with_custom_procs.yaml'], ['parsed tests']).returns('test source')

    regions, rules_by_month, custom_methods, tests = @generator.parse_definition_files(files)
    test_src = @generator.generate_definition_source("test", files, regions, rules_by_month, custom_methods, tests)[1]

    assert_equal 'test source', test_src
  end
end
