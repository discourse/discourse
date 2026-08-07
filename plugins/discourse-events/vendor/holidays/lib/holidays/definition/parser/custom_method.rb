require 'holidays/definition/entity/custom_method'

module Holidays
  module Definition
    module Parser
      class CustomMethod
        def initialize(validator)
          @validator = validator
        end

        def call(methods)
          return {} if methods.nil? || methods.empty?

          validate!(methods)

          custom_methods = {}

          methods.each do |name, pieces|
            arguments = parse_arguments!(pieces["arguments"])

            custom_methods[method_key(name, arguments)] = Entity::CustomMethod.new({
              name: name,
              arguments: arguments,
              source: pieces["ruby"],
            })
          end

          custom_methods
        end

        private

        def validate!(methods)
          raise ArgumentError unless methods.all? do |name, pieces|
            @validator.valid?(
              {
                :name => name,
                :arguments => pieces["arguments"],
                :source => pieces["ruby"]
              }
            )
          end
        end

        def parse_arguments!(arguments)
          splitArgs = arguments.split(",")
          parsedArgs = []

          splitArgs.each do |arg|
            parsedArgs << arg.strip
          end

          parsedArgs
        end

        def method_key(name, args)
          "#{name.to_s}(#{args_string(args)})"
        end

        def args_string(args)
          a = args.join(", ")
          a[0..-1]
        end
      end
    end
  end
end
