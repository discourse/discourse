class UsernameValidator
  def initialize(username)
    @username = username
    @errors = []
  end
  attr_accessor :errors
  attr_reader :username

  def user
    @user ||= User.new(user)
  end

  def valid_format?
    username_exist?
    username_length_min?
    username_length_max?
    username_char_valid?
    username_first_char_valid?
    errors.empty?
  end

  private

  def username_exist?
    return unless errors.empty?
    unless username
      self.errors << I18n.t(:'user.username.blank')
    end
  end

  def username_length_min?
    return unless errors.empty?
    if username.length < User.username_length.begin
      self.errors << I18n.t(:'user.username.short', min: User.username_length.begin)
    end
  end

  def username_length_max?
    return unless errors.empty?
    if username.length > User.username_length.end
      self.errors << I18n.t(:'user.username.long', max: User.username_length.end)
    end
  end

  def username_char_valid?
    return unless errors.empty?
    if username =~ /[^A-Za-z0-9_]/
      self.errors << I18n.t(:'user.username.characters')
    end
  end

  def username_first_char_valid?
    return unless errors.empty?
    if username[0,1] =~ /[^A-Za-z0-9]/
      self.errors << I18n.t(:'user.username.must_begin_with_alphanumeric')
    end
  end
end
