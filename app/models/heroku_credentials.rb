class HerokuCredentials

  ENCRYPTION_SEPARATOR = '[USER_ENCRYPTION_SEPARATOR]'
  ENCRYPTOR = ActiveSupport::MessageEncryptor.new(ENV['COOKIE_ENCRYPTION_SECRET'])

  attr_reader :email, :heroku_uid

  def initialize(attribs = {})
    attribs.each{ |k,v| instance_variable_set(:"@#{k}", v) }
  end

  def encrypt
    str = [@email, @heroku_uid].join(ENCRYPTION_SEPARATOR)
    ENCRYPTOR.encrypt_and_sign(str)
  end

  def self.decrypt(str)
    email, heroku_uid = ENCRYPTOR.decrypt_and_verify(str).split(ENCRYPTION_SEPARATOR)
    new email: email, heroku_uid: heroku_uid
  end
end