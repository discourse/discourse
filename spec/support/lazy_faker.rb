# frozen_string_literal: true

module LazyFaker
  def const_missing(name)
    require "faker"
    return const_get(name, false) if const_defined?(name, false)

    super
  end
end

Faker.singleton_class.prepend(LazyFaker)
