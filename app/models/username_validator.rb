class UsernameValidator

  def initialize(username)
    @username = username
    @error = []
  end
  attr_accessor :error
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
    error.blank?
  end

  private

  def username_exist?
    return unless error.empty?
    unless username
      self.error = I18n.t(:'user.username.blank')
    end
  end

  def username_length_min?
    return unless error.empty?
    if username.length < User.username_length.begin
      self.error = I18n.t(:'user.username.short', min: User.username_length.begin)
    end
  end

  def username_length_max?
    return unless error.empty?
    if username.length > User.username_length.end
      self.error = I18n.t(:'user.username.long', max: User.username_length.end)
    end
  end

  def username_char_valid?
    return unless error.empty?
    if username =~ /[^A-Za-z0-9_]/
      self.error = I18n.t(:'user.username.characters')
    end
  end

  def username_first_char_valid?
    return unless error.empty?
    if username[0,1] =~ /[^A-Za-z0-9]/
      self.error = I18n.t(:'user.username.must_begin_with_alphanumeric')
    end
  end

end
