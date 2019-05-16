# frozen_string_literal: true

unless ::Regexp.instance_methods.include?(:match?)
  class ::Regexp
    # this is the fast way of checking a regex (zero string allocs) added in Ruby 2.4
    # backfill it for now
    def match?(string)
      !!(string =~ self)
    end
  end
end
