class UnixCrypt::DES < UnixCrypt::Base
  def self.hash(*args)
    raise "Unimplemented for DES"
  end

  protected
  def self.construct_password(password, salt, rounds)
    password.crypt(salt)
  end

  def self.default_salt_length; 2; end
  def self.max_salt_length; 2; end
end
