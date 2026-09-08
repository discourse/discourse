# frozen_string_literal: true

# Modified version of: https://github.com/steventen/base62-rb

module Base62
  KEYS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  KEYS_HASH = KEYS.each_char.with_index.to_h
  BASE = KEYS.length

  class << self
    # Encodes base10 (decimal) number to base62 string.
    def encode(num)
      return "0" if num == 0
      return nil if num < 0

      str = ""
      while num > 0
        # prepend base62 characters
        str = KEYS[num % BASE] + str
        num = num / BASE
      end
      str
    end

    # Decodes base62 string to a base10 (decimal) number.
    def decode(str)
      num = 0
      i = 0
      len = str.length - 1
      # while loop is faster than each_char or other 'idiomatic' way
      while i < str.length
        pow = BASE**(len - i)
        num += KEYS_HASH[str[i]] * pow
        i += 1
      end
      num
    end
  end
end
