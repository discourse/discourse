# frozen_string_literal: true

class ThemeSettingsManager::Upload < ThemeSettingsManager
  def value
    has_record? ? cdn_url(db_record.value) : default
  end

  def default
    upload_id = default_upload_id
    return if upload_id.blank?

    cdn_url(upload_id)
  end

  def value=(new_value)
    if new_value.present?
      if new_value == default
        new_value = default_upload_id
      else
        upload = ::Upload.find_by(url: new_value)
        new_value = upload.id if upload.present?
      end
    end

    super(new_value)
  end

  private

  def cdn_url(upload_id)
    return if upload_id.blank?

    upload = ::Upload.find_by_id(upload_id.to_i)
    return if upload.blank?

    Discourse.store.cdn_url(upload.url)
  end

  def default_upload_id
    theme_field =
      theme.theme_fields.find_by(name: @default, type_id: ThemeField.types[:theme_upload_var])
    return if theme_field.blank?

    theme_field.upload_id
  end
end
