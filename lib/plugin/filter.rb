# frozen_string_literal: true

# this concept is borrowed straight out of wordpress
module Plugin
  class Filter
    def self.manager
      @manager ||= FilterManager.new
    end

    def self.register(name, &blk)
      manager.register(name, &blk)
    end

    def self.apply(name, context, result)
      manager.apply(name, context, result)
    end

  end
end
