module Holidays
  module Definition
    module Repository
      # ==== Benchmarks
      #
      # Lookup Easter Sunday, with caching, by number of iterations:
      #
      #       user     system      total        real
      # 0001  0.000000   0.000000   0.000000 (  0.000000)
      # 0010  0.000000   0.000000   0.000000 (  0.000000)
      # 0100  0.078000   0.000000   0.078000 (  0.078000)
      # 1000  0.641000   0.000000   0.641000 (  0.641000)
      # 5000  3.172000   0.015000   3.187000 (  3.219000)
      #
      # Lookup Easter Sunday, without caching, by number of iterations:
      #
      #       user     system      total        real
      # 0001  0.000000   0.000000   0.000000 (  0.000000)
      # 0010  0.016000   0.000000   0.016000 (  0.016000)
      # 0100  0.125000   0.000000   0.125000 (  0.125000)
      # 1000  1.234000   0.000000   1.234000 (  1.234000)
      # 5000  6.094000   0.031000   6.125000 (  6.141000)
      class ProcResultCache
        def initialize
          @proc_cache = {}
        end

        def lookup(function, *function_arguments)
          validate!(function, function_arguments)

          proc_key = build_proc_key(function, function_arguments)
          @proc_cache[proc_key] = function.call(*function_arguments) unless @proc_cache[proc_key]
          @proc_cache[proc_key]
        end

        private

        def validate!(function, function_arguments)
          raise ArgumentError.new("function must be a proc") unless function.is_a?(Proc)
          function_arguments.each do |arg|
            raise ArgumentError.new("function arguments '#{function_arguments}' must contain either integers or dates") unless arg.is_a?(Integer) || arg.is_a?(Date) || arg.is_a?(Symbol)
          end
        end

        def build_proc_key(function, function_arguments)
          Digest::MD5.hexdigest("#{function.to_s}_#{function_arguments.join('_')}")
        end
      end
    end
  end
end
