class PasswordValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    return unless record.password_required?
    if value.nil?
      record.errors.add(attribute, :blank)
    elsif value.length < SiteSetting.min_password_length
      record.errors.add(attribute, :too_short, count: SiteSetting.min_password_length)
    end
  end

end
