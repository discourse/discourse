module Holidays
  module Definition
    module Decorator
      class CustomMethodSource
        def call(proc)
          validate!(proc)

          method_name = proc.name
          args = args_string(proc.arguments)
          source = proc.source

          "\"#{method_name.to_s}(#{args})\" => Proc.new { |#{args}|\n#{source}}"
        end

        private

        def validate!(proc)
          raise ArgumentError if proc.name.nil? || proc.name == ""
          raise ArgumentError if proc.arguments.nil? || !proc.arguments.is_a?(Array) || proc.arguments.empty?
          raise ArgumentError if proc.source.nil? || proc.source == ""
        end

        def args_string(args)
          a = args.join(", ")
          a[0..-1]
        end
      end
    end
  end
end
