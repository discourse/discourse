require 'yaml'

#FIXME This whole file is my next refactor target. We do wayyyyy too much by
#      convention here. We need hard and fast rules and explicit errors when you
#      try to parse something that isn't allowed. So if you are a dev recognize
#      that a lot of the guard statements in here are to codify existing legacy
#      logic. The fact is that we already require these guards, we just don't
#      enforce it explicitly. Now we will. And by doing so things will begin
#      to look very, very messy.
module Holidays
  module Definition
    module Context
      class Generator
        def initialize(custom_method_parser, custom_method_source_decorator, custom_methods_repository, test_parser, test_source_generator, module_source_generator)
          @custom_method_parser = custom_method_parser
          @custom_method_source_decorator = custom_method_source_decorator
          @custom_methods_repository = custom_methods_repository
          @test_parser = test_parser
          @test_source_generator = test_source_generator
          @module_source_generator = module_source_generator
        end

        def parse_definition_files(files)
          raise ArgumentError, "Must have at least one file to parse" if files.nil? || files.empty?

          all_regions = []
          all_rules_by_month = {}
          all_custom_methods = {}
          all_tests = []

          files.flatten!

          files.each do |file|
            definition_file = YAML.load_file(file)

            custom_methods = @custom_method_parser.call(definition_file['methods'])

            regions, rules_by_month = parse_month_definitions(definition_file['months'], custom_methods)

            all_regions << regions.flatten

            all_rules_by_month.merge!(rules_by_month) { |month, existing, new|
              existing << new
              existing.flatten!
            }

            #FIXME This is a problem. We will have a 'global' list of methods. That's always bad. What effects will this have?
            # This is an existing problem (just so we are clear). An issue would be extremely rare because we are generally parsing
            # single files/custom files. But it IS possible that we would parse a bunch of things at the same time and step
            # on each other so we need a solution.
            all_custom_methods.merge!(custom_methods)

            all_tests += @test_parser.call(definition_file['tests'])
          end

          all_regions.flatten!.uniq!

          [all_regions, all_rules_by_month, all_custom_methods, all_tests]
        end

        def generate_definition_source(module_name, files, regions, rules_by_month, custom_methods, tests)
          month_strings = generate_month_definition_strings(rules_by_month, custom_methods)

          # Build the custom methods string
          custom_method_string = ''
          custom_methods.each do |key, code|
            custom_method_string << @custom_method_source_decorator.call(code) + ",\n\n"
          end

          module_src = @module_source_generator.call(module_name, files, regions, month_strings, custom_method_string)
          test_src = @test_source_generator.call(module_name, files, tests)

          return module_src, test_src || ''
        end

        private

        #FIXME This should be a 'month_definitions_parser' like the above parser
        def parse_month_definitions(month_definitions, parsed_custom_methods)
          regions = []
          rules_by_month = {}

          if month_definitions
            month_definitions.each do |month, definitions|
              rules_by_month[month] = [] unless rules_by_month[month]
              definitions.each do |definition|
                rule = {}

                definition.each do |key, val|
                  # Ruby 2.4 doesn't have the `transform_keys` method. Once we drop 2.4 support we can
                  # use `val.transform_keys!(&:to_sym) if val.is_a?(Hash)` instead of this `if` statement.
                  if val.is_a?(Hash)
                    val = val.keys.each_with_object({}) do |k, result|
                      result[k.to_sym] = val[k]
                    end
                  end

                  rule[key.to_sym] = val
                end

                if rule[:year_ranges] && rule[:year_ranges].key?(:between)
                  start_year = rule[:year_ranges][:between]["start"].to_i
                  end_year = rule[:year_ranges][:between]["end"].to_i

                  rule[:year_ranges][:between] = Range.new(start_year, end_year)
                end

                rule[:regions] = rule[:regions].collect { |r| r.to_sym }
                regions << rule[:regions]

                exists = false
                rules_by_month[month].each do |ex|
                  if ex[:name] == rule[:name] and ex[:wday] == rule[:wday] and ex[:mday] == rule[:mday] and ex[:week] == rule[:week] and ex[:type] == rule[:type] and ex[:function] == rule[:function] and ex[:observed] == rule[:observed] and ex[:year_ranges] == rule[:year_ranges]
                    ex[:regions] << rule[:regions].flatten
                    exists = true
                  end
                end

                unless exists
                  # This will add in the custom method arguments so they are immediately
                  # available for 'on the fly' def loading.
                  if rule[:function]
                    rule[:function_arguments] = get_function_arguments(rule[:function], parsed_custom_methods)
                  end

                  rules_by_month[month] << rule
                end
              end
            end
          end

          [regions, rules_by_month]
        end

        #FIXME This should really be split out and tested with its own unit tests.
        def generate_month_definition_strings(rules_by_month, parsed_custom_methods)
          month_strings = []

          rules_by_month.each do |month, rules|
            month_string = "      #{month.to_s} => ["
            rule_strings = []
            rules.each do |rule|
              string = '{'
              if rule[:mday]
                string << ":mday => #{rule[:mday]}, "
              end

              if rule[:function]
                string << ":function => \"#{rule[:function].to_s}\", "

                # We need to add in the arguments so we can know what to send in when calling the custom proc during holiday lookups.
                # NOTE: the allowed arguments are enforced in the custom methods parser.
                string << ":function_arguments => #{get_function_arguments(rule[:function], parsed_custom_methods)}, "

                if rule[:function_modifier]
                  string << ":function_modifier => #{rule[:function_modifier].to_s}, "
                end
              end

              # This is the 'else'. It is possible for mday AND function
              # to be set but this is the fallback. This whole area
              # needs to be reworked!
              if string == '{'
                string << ":wday => #{rule[:wday]}, :week => #{rule[:week]}, "
              end

              if rule[:year_ranges] && rule[:year_ranges].is_a?(Hash)
                selector = rule[:year_ranges].keys.first
                value = rule[:year_ranges][selector]

                string << ":year_ranges => { :#{selector} => #{value} },"
              end

              if rule[:observed]
                string << ":observed => \"#{rule[:observed].to_s}\", "
                string << ":observed_arguments => #{get_function_arguments(rule[:observed], parsed_custom_methods)}, "
              end

              if rule[:type]
                string << ":type => :#{rule[:type]}, "
              end

              # shouldn't allow the same region twice
              string << ":name => \"#{rule[:name]}\", :regions => [:" + rule[:regions].uniq.join(', :') + "]}"
              rule_strings << string
            end
            month_string << rule_strings.join(",\n            ") + "]"
            month_strings << month_string
          end

          return month_strings
        end

        # This method sucks. The issue here is that the custom methods repo has the 'general' methods (like easter)
        # but the 'parsed_custom_methods' have the recently parsed stuff. We don't load those until they are needed later.
        # This entire file is a refactor target so I am adding some tech debt to get me over the hump.
        # What we should do is ensure that all custom methods are loaded into the repo as soon as they are parsed
        # so we only have one place to look.
        def get_function_arguments(function_id, parsed_custom_methods)
          if method = @custom_methods_repository.find(function_id)
            method.parameters.collect { |arg| arg[1] }
          elsif method = parsed_custom_methods[function_id]
            method.arguments.collect { |arg| arg.to_sym }
          end
        end
      end
    end
  end
end
