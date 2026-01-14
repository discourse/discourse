module Holidays
  module Definition
    module Decorator
      class CustomMethodProc
        def call(proc)
          validate!(proc)

          eval("Proc.new { |#{parse_arguments(proc.arguments)}|
               #{proc.source}
          }")
        end

        private

        def validate!(proc)
          raise ArgumentError if proc.name.nil? || proc.name.empty?
          raise ArgumentError if proc.arguments.nil? || proc.arguments.empty?
          raise ArgumentError if proc.source.nil? || proc.source.empty?
        end

        def parse_arguments(args)
          a = args.join(", ")
          a[0..-1]
        end
      end
    end
  end
end
