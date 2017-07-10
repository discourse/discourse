class UnixCrypt::MD5 < UnixCrypt::Base
protected
  def self.digest; Digest::MD5; end
  def self.length; 16; end
  def self.default_salt_length; 8; end
  def self.max_salt_length; 8; end
  def self.identifier; 1; end

  def self.byte_indexes
    [[0, 6, 12], [1, 7, 13], [2, 8, 14], [3, 9, 15], [4, 10, 5], [nil, nil, 11]]
  end

  def self.internal_hash(password, salt, ignored = nil)
    salt = salt[0..7]

    b = digest.digest("#{password}#{salt}#{password}")
    a_string = "#{password}$1$#{salt}#{b * (password.length/length)}#{b[0...password.length % length]}"

    password_length = password.length
    while password_length > 0
      a_string += (password_length & 1 != 0) ? "\x0" : password[0].chr
      password_length >>= 1
    end

    input = digest.digest(a_string)

    1000.times do |index|
      c_string = ((index & 1 != 0) ? password : input)
      c_string += salt unless index % 3 == 0
      c_string += password unless index % 7 == 0
      c_string += ((index & 1 != 0) ? input : password)
      input = digest.digest(c_string)
    end

    input
  end
end
