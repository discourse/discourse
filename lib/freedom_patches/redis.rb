# https://github.com/redis/redis-rb/pull/591
class Redis
  class Client
    alias_method :old_initialize, :initialize

    def initialize(options = {})
      old_initialize(options)

      if options.include?(:connector) && options[:connector].is_a?(Class)
        @connector = options[:connector].new(@options)
      end
    end
  end
end
