# https://github.com/bwalding/ruby-drupal-hash


###############################################################################
#   Copyright 2013 Ben Walding
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
###############################################################################

=begin
RubyDrupalHash.new.verify("password1234", "$S$DeIZ1KTE.VzRvudZ5.xgOakipuMFrVyPmRdWTjAdYieWj27NMglI")
=end
class RubyDrupalHash
  DRUPAL_HASH_COUNT = 15
  DRUPAL_MIN_HASH_COUNT = 7
  DRUPAL_MAX_HASH_COUNT = 30
  DRUPAL_HASH_LENGTH = 55
  ITOA64 = './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

  HASH = Digest::SHA2.new(512)

  def verify(password, hashed_password)
    return false if password.nil? or hashed_password.nil?

    setting = hashed_password[0..11]
    if setting[0] != '$' or setting[2] != '$'
      # Wrong hash format
      return false
    end

    count_log2 = ITOA64.index(setting[3])

    if count_log2 < DRUPAL_MIN_HASH_COUNT or count_log2 > DRUPAL_MAX_HASH_COUNT
      return false
    end

    salt = setting[4..4+7]

    if salt.length != 8
      return false
    end

    count = 2 ** count_log2

    pass_hash = HASH.digest(salt + password)

    1.upto(count) do |i|
      pass_hash = HASH.digest(pass_hash.force_encoding(Encoding::UTF_8) + password)
    end

    hash_length = pass_hash.length

    output = setting + _password_base64_encode(pass_hash, hash_length)

    if output.length != 98
      return false
    end

    return output[0..(DRUPAL_HASH_LENGTH-1)] == hashed_password
  end

  def _password_base64_encode(to_encode, count)
    output = ''
    i = 0
    while true
      value = (to_encode[i]).ord

      i += 1

      output = output + ITOA64[value & 0x3f]
      if i < count
        value |= (to_encode[i].ord) << 8
      end

      output = output + ITOA64[(value >> 6) & 0x3f]

      if i >= count
        break
      end

      i += 1

      if i < count
        value |= (to_encode[i].ord) << 16
      end

      output = output + ITOA64[(value >> 12) & 0x3f]

      if i >= count
        break
      end

      i += 1

      output = output + ITOA64[(value >> 18) & 0x3f]

      if i >= count
        break
      end

    end
    return output
  end
end
