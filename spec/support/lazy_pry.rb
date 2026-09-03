# frozen_string_literal: true

module LazyPry
  def pry(...)
    require "pry"
    require "pry-rails"
    LazyPry.remove_method(:pry)
    public_send(:pry, ...)
  end
end

Object.prepend(LazyPry)
