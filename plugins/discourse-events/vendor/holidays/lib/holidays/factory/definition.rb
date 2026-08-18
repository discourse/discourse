require 'holidays/definition/context/generator'
require 'holidays/definition/context/merger'
require 'holidays/definition/context/function_processor'
require 'holidays/definition/context/load'
require 'holidays/definition/decorator/custom_method_proc'
require 'holidays/definition/decorator/custom_method_source'
require 'holidays/definition/decorator/test'
require 'holidays/definition/generator/module'
require 'holidays/definition/generator/regions'
require 'holidays/definition/generator/test'
require 'holidays/definition/parser/custom_method'
require 'holidays/definition/parser/test'
require 'holidays/definition/repository/holidays_by_month'
require 'holidays/definition/repository/regions'
require 'holidays/definition/repository/cache'
require 'holidays/definition/repository/proc_result_cache'
require 'holidays/definition/repository/custom_methods'
require 'holidays/definition/validator/custom_method'
require 'holidays/definition/validator/region'
require 'holidays/definition/validator/test'

module Holidays
  module Factory
    module Definition
      class << self
        def file_parser
          Holidays::Definition::Context::Generator.new(
            custom_method_parser,
            custom_method_source_decorator,
            custom_methods_repository,
            test_parser,
            test_generator,
            module_generator,
          )
        end

        def source_generator
          Holidays::Definition::Context::Generator.new(
            custom_method_parser,
            custom_method_source_decorator,
            custom_methods_repository,
            test_parser,
            test_generator,
            module_generator,
          )
        end

        def function_processor
          Holidays::Definition::Context::FunctionProcessor.new(
            custom_methods_repository,
            proc_result_cache_repository,
          )
        end

        def merger
          Holidays::Definition::Context::Merger.new(
            holidays_by_month_repository,
            regions_repository,
            custom_methods_repository,
          )
        end

        def custom_method_parser
          Holidays::Definition::Parser::CustomMethod.new(
            custom_method_validator,
          )
        end

        def custom_method_proc_decorator
          Holidays::Definition::Decorator::CustomMethodProc.new
        end

        def custom_method_source_decorator
          Holidays::Definition::Decorator::CustomMethodSource.new
        end

        def region_validator
          Holidays::Definition::Validator::Region.new(
            regions_repository
          )
        end

        def custom_method_validator
          Holidays::Definition::Validator::CustomMethod.new
        end

        def holidays_by_month_repository
          @holidays_repo ||= Holidays::Definition::Repository::HolidaysByMonth.new
        end

        def regions_repository
          @regions_repo ||= Holidays::Definition::Repository::Regions.new(
            Holidays::REGIONS,
            Holidays::PARENT_REGION_LOOKUP,
          )
        end

        def cache_repository
          @cache_repo ||= Holidays::Definition::Repository::Cache.new
        end

        def proc_result_cache_repository
          @proc_result_cache_repo ||= Holidays::Definition::Repository::ProcResultCache.new
        end

        def custom_methods_repository
          @custom_methods_repository ||= Holidays::Definition::Repository::CustomMethods.new
        end

        def regions_generator
          Holidays::Definition::Generator::Regions.new
        end

        def loader
          Holidays::Definition::Context::Load.new(
            merger,
            Holidays::FULL_DEFINITIONS_PATH,
          )
        end

        def module_generator
          Holidays::Definition::Generator::Module.new
        end

        def test_generator
          Holidays::Definition::Generator::Test.new(
            test_decorator,
          )
        end

        def test_decorator
          Holidays::Definition::Decorator::Test.new
        end

        def test_parser
          Holidays::Definition::Parser::Test.new(
            Holidays::Definition::Validator::Test.new,
          )
        end
      end
    end
  end
end
