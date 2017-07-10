require 'digest'
require 'securerandom'

module UnixCrypt
  VERSION = "1.3.0"

  Error = Class.new(StandardError)
  SaltTooLongError = Class.new(Error)

  def self.valid?(password, string)
    # Handle the original DES-based crypt(3)
    return password.crypt(string) == string if string.length == 13

    # All other types of password follow a standard format
    return false unless m = string.match(/\A\$([156])\$(?:rounds=(\d+)\$)?(.+)\$(.+)/)

    hash = IDENTIFIER_MAPPINGS[m[1]].hash(password, m[3], m[2] && m[2].to_i)
    hash == m[4]
  end
end

require 'unix_crypt/base'
require 'unix_crypt/des'
require 'unix_crypt/md5'
require 'unix_crypt/sha'

UnixCrypt::IDENTIFIER_MAPPINGS = {
  '1' => UnixCrypt::MD5,
  '5' => UnixCrypt::SHA256,
  '6' => UnixCrypt::SHA512
}
