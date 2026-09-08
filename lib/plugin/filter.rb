# frozen_string_literal: true

# this concept is borrowed straight out of wordpress
module Plugin
  class Filter
    class << self
      def manager
        @manager ||= FilterManager.new
      end

      def register(name, &blk)
        manager.register(name, &blk)
      end

      def apply(name, context, result)
        manager.apply(name, context, result)
      end
    end
  end
end
