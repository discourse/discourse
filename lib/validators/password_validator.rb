# frozen_string_literal: true

class PasswordValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless record.password_validation_required?

    record.errors.add(attribute, :blank) if value.blank?
  end
end
