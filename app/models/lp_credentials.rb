class LpCredentials

  ENCRYPTION_SEPARATOR = '[USER_ENCRYPTION_SEPARATOR]'
  ENCRYPTOR = ActiveSupport::MessageEncryptor.new(ENV['COOKIE_ENCRYPTION_SECRET'])

  attr_reader :email, :lessonplanet_uid

  def initialize(attribs = {})
    attribs.each{ |k,v| instance_variable_set(:"@#{k}", v) }
  end

  def encrypt
    str = [@email, @lessonplanet_uid].join(ENCRYPTION_SEPARATOR)
    ENCRYPTOR.encrypt_and_sign(str)
  end

  def self.decrypt(str)
    email, lessonplanet_uid = ENCRYPTOR.decrypt_and_verify(str).split(ENCRYPTION_SEPARATOR)
    new email: email, lessonplanet_uid: lessonplanet_uid
  end
end
