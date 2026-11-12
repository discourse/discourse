## encoding: utf-8

require 'yaml'

require_relative 'error'
require_relative 'definition_validator'
require_relative 'custom_method_validator'
require_relative 'month_validator'
require_relative 'test_validator'

definitions_path = '/../../'

module Definitions
  class Validate
    def initialize(path, definition_validator)
      @path = path
      @definition_validator = definition_validator
    end

    def call
      path = File.expand_path(File.dirname(__FILE__)) + @path

      definition_count = 0

      Dir.foreach(path) do |item|
        next if item == '.' or item == '..'

        target = path+item
        next if File.extname(target) != '.yaml'
        next if item == 'index.yaml'

        definition_count += 1

        begin
          definition_file = YAML.load(File.open(target))
          validate!(definition_file)
        rescue Psych::SyntaxError => e
          puts "Failed on file '#{target}', YAML parse error: #{e}"
          puts "This means your YAML is somehow invalid. Test your file on something like yamllint.com to find the issue."
          exit
        rescue => e
          puts "Failed on file '#{target}', error: #{e}"
          exit
        end
      end

      puts "Success!"
      puts "Definition count: #{definition_count}"
    end

    private

    def validate!(definition)
      raise StandardError unless @definition_validator.call(definition)
    end
  end
end

Definitions::Validate.new(
  definitions_path,
  Definitions::Validation::Definition.new(
    Definitions::Validation::CustomMethod.new,
    Definitions::Validation::Month.new,
    Definitions::Validation::Test.new,
  ),
).call
