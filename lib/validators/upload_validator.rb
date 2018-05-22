require_dependency "file_helper"

module Validators; end

class Validators::UploadValidator < ActiveModel::Validator

  def validate(upload)
    # staff can upload any file in PM
    if upload.for_private_message && SiteSetting.allow_staff_to_upload_any_file_in_pm
      return true if upload.user&.staff?
    end

    # check the attachment blacklist
    if upload.for_group_message && SiteSetting.allow_all_attachments_for_group_messages
      return upload.original_filename =~ SiteSetting.attachment_filename_blacklist_regex
    end

    extension = File.extname(upload.original_filename)[1..-1] || ""

    if is_authorized?(upload, extension)
      if FileHelper.is_image?(upload.original_filename)
        authorized_image_extension(upload, extension)
        maximum_image_file_size(upload)
      else
        authorized_attachment_extension(upload, extension)
        maximum_attachment_file_size(upload)
      end
    end
  end

  def is_authorized?(upload, extension)
    extension_authorized?(upload, extension, authorized_extensions(upload))
  end

  def authorized_image_extension(upload, extension)
    extension_authorized?(upload, extension, authorized_images(upload))
  end

  def maximum_image_file_size(upload)
    maximum_file_size(upload, "image")
  end

  def authorized_attachment_extension(upload, extension)
    extension_authorized?(upload, extension, authorized_attachments(upload))
  end

  def maximum_attachment_file_size(upload)
    maximum_file_size(upload, "attachment")
  end

  private

  def extensions_to_set(exts)
    extensions = Set.new

    exts
      .gsub(/[\s\.]+/, "")
      .downcase
      .split("|")
      .each { |extension| extensions << extension unless extension.include?("*") }

    extensions
  end

  def authorized_extensions(upload)
    extensions = if upload.for_theme
      SiteSetting.theme_authorized_extensions
    elsif upload.for_export
      SiteSetting.export_authorized_extensions
    else
      SiteSetting.authorized_extensions
    end
    extensions_to_set(extensions)
  end

  def authorized_images(upload)
    authorized_extensions(upload) & FileHelper.images
  end

  def authorized_attachments(upload)
    authorized_extensions(upload) - FileHelper.images
  end

  def authorizes_all_extensions?(upload)
    if upload.user&.staff?
      return true if SiteSetting.authorized_extensions_for_staff.include?("*")
    end
    extensions = if upload.for_theme
      SiteSetting.theme_authorized_extensions
    elsif upload.for_export
      SiteSetting.export_authorized_extensions
    else
      SiteSetting.authorized_extensions
    end
    extensions.include?("*")
  end

  def extension_authorized?(upload, extension, extensions)
    return true if authorizes_all_extensions?(upload)

    staff_extensions = Set.new
    if upload.user&.staff?
      staff_extensions = extensions_to_set(SiteSetting.authorized_extensions_for_staff)
      return true if staff_extensions.include?(extension.downcase)
    end

    unless authorized = extensions.include?(extension.downcase)
      message = I18n.t("upload.unauthorized", authorized_extensions: (extensions | staff_extensions).to_a.join(", "))
      upload.errors.add(:original_filename, message)
    end

    authorized
  end

  def maximum_file_size(upload, type)
    max_size_kb = SiteSetting.send("max_#{type}_size_kb")
    max_size_bytes = max_size_kb.kilobytes

    if upload.filesize > max_size_bytes
      message = I18n.t("upload.#{type}s.too_large", max_size_kb: max_size_kb)
      upload.errors.add(:filesize, message)
    end
  end

end
