require_dependency 'user'

class UsernameValidator
  # Public: Perform the validation of a field in a given object
  # it adds the errors (if any) to the object that we're giving as parameter
  #
  # object - Object in which we're performing the validation
  # field_name - name of the field that we're validating
  #
  # Example: UsernameValidator.perform_validation(user, 'name')
  def self.perform_validation(object, field_name)
    validator = UsernameValidator.new(object.send(field_name))
    unless validator.valid_format?
      validator.errors.each { |e| object.errors.add(field_name.to_sym, e) }
    end
  end

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
    username_last_char_valid?
    username_no_double_special?
    username_does_not_end_with_confusing_suffix?
    errors.empty?
  end

  CONFUSING_EXTENSIONS ||= /\.(js|json|css|htm|html|xml|jpg|jpeg|png|gif|bmp|ico|tif|tiff|woff)$/i

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
    if username =~ /[^\w.-]/
      self.errors << I18n.t(:'user.username.characters')
    end
  end

  def username_first_char_valid?
    return unless errors.empty?
    if username[0] =~ /\W/
      self.errors << I18n.t(:'user.username.must_begin_with_alphanumeric_or_underscore')
    end
  end

  def username_last_char_valid?
    return unless errors.empty?
    if username[-1] =~ /[^A-Za-z0-9]/
      self.errors << I18n.t(:'user.username.must_end_with_alphanumeric')
    end
  end

  def username_no_double_special?
    return unless errors.empty?
    if username =~ /[-_.]{2,}/
      self.errors << I18n.t(:'user.username.must_not_contain_two_special_chars_in_seq')
    end
  end

  def username_does_not_end_with_confusing_suffix?
    return unless errors.empty?
    if username =~ CONFUSING_EXTENSIONS
      self.errors << I18n.t(:'user.username.must_not_end_with_confusing_suffix')
    end
  end
end
