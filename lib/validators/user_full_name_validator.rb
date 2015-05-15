class UserFullNameValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    if SiteSetting.full_name_required && !record.name.present?
      record.errors.add(attribute, :blank)
    end
  end
end
