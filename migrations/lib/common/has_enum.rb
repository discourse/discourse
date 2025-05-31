# frozen_string_literal: true

module Migrations
  module HasEnum
    def enum(name, *args)
      mod = Module.new { extend Enum }

      mod.define_values(*args)

      const_set(name.to_s.capitalize, mod)

      define_method(name) { mod }
      define_singleton_method(name) { mod }
    end
  end
end
