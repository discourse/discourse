# TODO: Remove once we upgrade to Rails 6.1
# Copied implementation from https://github.com/rails/rails/pull/38169
module ActionDispatch
  class MiddlewareStack
    def move(target, source)
      source_index = assert_index(source, :before)
      source_middleware = middlewares.delete_at(source_index)

      target_index = assert_index(target, :before)
      middlewares.insert(target_index, source_middleware)
    end
    alias_method :move_before, :move

    def move_after(target, source)
      source_index = assert_index(source, :after)
      source_middleware = middlewares.delete_at(source_index)

      target_index = assert_index(target, :after)
      middlewares.insert(target_index + 1, source_middleware)
    end
  end
end

module Rails
  module Configuration
    class MiddlewareStackProxy
      def move_before(*args, &block)
        @delete_operations << -> middleware { middleware.send(__method__, *args, &block) }
      end

      alias :move :move_before

      def move_after(*args, &block)
        @delete_operations << -> middleware { middleware.send(__method__, *args, &block) }
      end
    end
  end
end
