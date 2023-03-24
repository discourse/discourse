# frozen_string_literal: true

class UserFullNameValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :blank) if SiteSetting.full_name_required && !record.name.present?
  end
end
