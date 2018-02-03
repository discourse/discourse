class String
  # new to Ruby 2.4, fastest way of matching a string to a regex
  unless method_defined? :match?
    def match?(regex)
      !!(self =~ regex)
    end
  end
end
