# frozen_string_literal: true

# Modified version of: https://github.com/steventen/base62-rb

module Base62
  KEYS ||= "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".freeze
  KEYS_HASH ||= KEYS.each_char.with_index.to_h
  BASE ||= KEYS.length

  # Encodes base10 (decimal) number to base62 string.
  def self.encode(num)
    return "0" if num == 0
    return nil if num < 0

    str = ""
    while num > 0
      # prepend base62 charaters
      str = KEYS[num % BASE] + str
      num = num / BASE
    end
    str
  end

  # Decodes base62 string to a base10 (decimal) number.
  def self.decode(str)
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
