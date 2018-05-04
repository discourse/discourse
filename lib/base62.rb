# 不确定为什么要用 Base62， Base64 似乎是一个更通用的标准
# 看 Github 链接，Base62 is usually used for short URLs.
# https://paragonie.com/blog/2015/09/comprehensive-guide-url-parameter-encryption-in-php
# 这个看起来挺相关的，暂时没时间看完。总之似乎就是为了 URL 编码，方便数据库存

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
