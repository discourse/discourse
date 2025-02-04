# frozen_string_literal: true

class UserFullNameValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if SiteSetting.full_name_requirement == "required_at_signup" && !record.name.present?
      record.errors.add(attribute, :blank)
    end
  end
end
