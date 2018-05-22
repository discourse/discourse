# precision was added to ceil in Ruby 2.4
class Float
  if (1.5).method(:ceil).arity == 0
    old_ceil = instance_method(:ceil)

    define_method(:ceil) do |ndigits = 0|
      if ndigits == 0
        old_ceil.bind(self).()
      else
        precision = 10**ndigits
        result = old_ceil.bind(self * precision).() / precision.to_f
        ndigits.negative? ? result.round : result
      end
    end
  end
end

class Integer
  if 1.method(:ceil).arity == 0
    old_ceil = instance_method(:ceil)

    define_method(:ceil) do |ndigits = 0|
      if ndigits == 0
        old_ceil.bind(self).()
      else
        precision = 10**ndigits

        if ndigits.negative?
          ((self * precision).ceil / precision).to_i
        else
          old_ceil.bind(self * precision).() / precision.to_f
        end
      end
    end
  end
end
