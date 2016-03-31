require_dependency "file_helper"

module Validators; end

class Validators::UploadValidator < ActiveModel::Validator

  def validate(upload)
    return true if upload.is_attachment_for_group_message && SiteSetting.allow_all_attachments_for_group_messages

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
    authorized_extensions(upload, extension, authorized_uploads)
  end

  def authorized_image_extension(upload, extension)
    authorized_extensions(upload, extension, authorized_images)
  end

  def maximum_image_file_size(upload)
    maximum_file_size(upload, "image")
  end

  def authorized_attachment_extension(upload, extension)
    authorized_extensions(upload, extension, authorized_attachments)
  end

  def maximum_attachment_file_size(upload)
    maximum_file_size(upload, "attachment")
  end

  private

  def authorized_uploads
    authorized_uploads = Set.new

    SiteSetting.authorized_extensions
      .tr(" ", "")
      .split("|")
      .each do |extension|
        next if extension.include?("*")
        authorized_uploads << (extension.start_with?(".") ? extension[1..-1] : extension).downcase
      end

    authorized_uploads
  end

  def authorized_images
    authorized_uploads & FileHelper.images
  end

  def authorized_attachments
    authorized_uploads - FileHelper.images
  end

  def authorizes_all_extensions?
    SiteSetting.authorized_extensions.include?("*")
  end

  def authorized_extensions(upload, extension, extensions)
    return true if authorizes_all_extensions?

    unless authorized = extensions.include?(extension.downcase)
      message = I18n.t("upload.unauthorized", authorized_extensions: extensions.to_a.join(", "))
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
