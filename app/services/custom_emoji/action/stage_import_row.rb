# frozen_string_literal: true

class CustomEmoji::Action::StageImportRow < Service::ActionBase
  UPLOAD_RETAIN_HOURS = 3

  option :reader
  option :row
  option :acting_user
  option :existing_emoji, optional: true

  def call
    with_image_tempfile do |image|
      return row.mark_invalid(I18n.t("emoji.import.validation.missing_image")) if image.nil?

      upload = create_upload(image)
      return row.mark_invalid(*upload.errors.full_messages) if !upload.persisted?

      upload.update_columns(retain_hours: UPLOAD_RETAIN_HOURS)
      row.stage(upload:, existing_emoji:)
    end
  end

  private

  def with_image_tempfile
    tempfile = Tempfile.new(["emoji_import_", File.extname(row.filename)])
    tempfile.binmode
    bytes_written =
      reader.stream_entry_to_file(
        row.filename,
        tempfile,
        max_bytes: SiteSetting.max_image_size_kb.kilobytes,
        required: false,
      )
    tempfile.rewind
    yield(bytes_written && tempfile)
  ensure
    tempfile.close!
  end

  def create_upload(image)
    UploadCreator.new(image, row.filename, type: "custom_emoji").create_for(acting_user.id)
  end
end
