# frozen_string_literal: true

require "csv"

class Admin::EmojiController < Admin::AdminController
  skip_before_action :check_xhr, only: [:export]

  IMPORT_PREVIEW_TTL = 2.hours.to_i
  IMPORT_MAX_ENTRIES = 1000
  IMPORT_MAX_BYTES = 500.megabytes
  IMPORT_MAX_COMPRESSION_RATIO = 20
  SUPPORTED_EXTENSIONS = %w[png gif svg].freeze

  def index
    render_serialized(Emoji.custom, EmojiSerializer, root: false)
  end

  # NOTE: This kind of custom logic also needs to be implemented to
  # be run in the ExternalUploadManager when a direct S3 upload is completed,
  # related to preventDirectS3Uploads in the UppyUploadMixin.
  #
  # Until then, preventDirectS3Uploads is set to true in the UppyUploadMixin.
  def create
    file = params[:file] || params[:files].first
    name = params[:name] || File.basename(file.original_filename, ".*")
    group = params[:group] ? params[:group].downcase : nil

    hijack do
      # fix the name
      name = File.basename(name, ".*")
      name = Emoji.sanitize_emoji_name(name)
      upload =
        UploadCreator.new(file.tempfile, file.original_filename, type: "custom_emoji").create_for(
          current_user.id,
        )

      good = true

      data =
        if upload.persisted?
          custom_emoji =
            CustomEmoji.new(name: name, upload: upload, group: group, user: current_user)

          if custom_emoji.save
            StaffActionLogger.new(current_user).log_custom_emoji_create(name, group: group)

            Emoji.clear_cache
            { name: custom_emoji.name, url: custom_emoji.upload.url, group: group }
          else
            good = false
            failed_json.merge(errors: custom_emoji.errors.full_messages)
          end
        else
          good = false
          failed_json.merge(errors: upload.errors.full_messages)
        end

      render json: data.as_json, status: good ? 200 : 422
    end
  end

  def export
    names = Array(params[:names]).map(&:to_s).reject(&:blank?)
    if names.empty?
      return(
        render json: failed_json.merge(errors: [I18n.t("emoji.export.no_selection")]),
               status: :unprocessable_entity
      )
    end

    emojis = CustomEmoji.where(name: names).includes(:upload)
    return render json: failed_json, status: :not_found if emojis.empty?

    temp_dir = Dir.mktmpdir("discourse_emoji_export_")

    begin
      csv_rows = []

      emojis.each do |emoji|
        filename = "#{emoji.name}.#{emoji.upload.extension}"
        File.binwrite(File.join(temp_dir, filename), emoji.upload.content)
        group = emoji.group.presence
        group = nil if group == "default"
        csv_rows << [emoji.name, group, filename]
      end

      CSV.open(File.join(temp_dir, "emojis.csv"), "w") do |csv|
        csv << %w[name group filename]
        csv_rows.each { |row| csv << row }
      end

      zip_path = Compression::Zip.new.compress(File.dirname(temp_dir), File.basename(temp_dir))
      send_data File.binread(zip_path),
                type: "application/zip",
                disposition: "attachment",
                filename: "emojis.zip"
    ensure
      FileUtils.rm_rf(temp_dir)
      File.delete(zip_path) if zip_path && File.exist?(zip_path)
    end
  end

  def import_preview
    zip_file = params[:file]
    if zip_file.blank?
      return(
        render json: failed_json.merge(errors: [I18n.t("emoji.import.missing_file")]),
               status: :unprocessable_entity
      )
    end

    rows = []
    upload_map = {}

    hijack do
      begin
        Compression::SafeZipReader.open(
          zip_file.tempfile.path,
          max_entries: IMPORT_MAX_ENTRIES,
          max_total_bytes: IMPORT_MAX_BYTES,
          max_compression_ratio: IMPORT_MAX_COMPRESSION_RATIO,
        ) do |reader|
          csv_data = reader.read_entry("emojis.csv", max_bytes: 1.megabyte, required: true)

          csv_rows = CSV.parse(csv_data, headers: true)

          filenames_seen = {}
          parsed_rows = []

          csv_rows.each_with_index do |row, idx|
            name = row["name"].to_s.strip
            group = row["group"].to_s.strip.downcase.presence
            group = nil if group == "default"
            filename = row["filename"].to_s.strip

            errors = validate_import_row(name, group, filename, filenames_seen)
            filenames_seen[filename] = true

            parsed_rows << {
              idx: idx,
              name: name,
              group: group,
              filename: filename,
              errors: errors,
            }
          end

          valid_names = parsed_rows.filter_map { |r| r[:name] if r[:errors].empty? }
          existing_by_name = CustomEmoji.where(name: valid_names).includes(:upload).index_by(&:name)

          parsed_rows.each do |parsed|
            idx = parsed[:idx]
            name = parsed[:name]
            group = parsed[:group]
            filename = parsed[:filename]
            errors = parsed[:errors]

            if errors.any?
              rows << {
                index: idx,
                name: name,
                group: group || "default",
                filename: filename,
                category: "invalid",
                errors: errors,
              }
              next
            end

            tmp_image = Tempfile.new(["emoji_import_", ".#{File.extname(filename).delete(".")}"])
            tmp_image.binmode

            begin
              bytes_written =
                reader.stream_entry_to_file(
                  filename,
                  tmp_image,
                  max_bytes: SiteSetting.max_image_size_kb.kilobytes,
                  required: false,
                )

              if bytes_written.nil?
                rows << {
                  index: idx,
                  name: name,
                  group: group || "default",
                  filename: filename,
                  category: "invalid",
                  errors: [I18n.t("emoji.import.validation.missing_filename")],
                }
                next
              end

              tmp_image.rewind

              upload =
                UploadCreator.new(tmp_image, filename, type: "custom_emoji").create_for(
                  current_user.id,
                )

              unless upload.persisted?
                rows << {
                  index: idx,
                  name: name,
                  group: group || "default",
                  filename: filename,
                  category: "invalid",
                  errors: upload.errors.full_messages,
                }
                next
              end

              upload.update_columns(retain_hours: 3)
              upload_map[filename] = upload.id

              category, existing_url, existing_group =
                classify_import_row(name, group, upload, existing_by_name[name])

              rows << {
                index: idx,
                name: name,
                group: group || "default",
                filename: filename,
                category: category,
                incoming_url: upload.url,
                existing_url: existing_url,
                existing_group: existing_group || "default",
              }
            ensure
              tmp_image.close!
            end
          end
        end
      rescue Compression::SafeZipReader::MissingEntryError
        return(
          render json: failed_json.merge(errors: [I18n.t("emoji.import.missing_csv")]),
                 status: :unprocessable_entity
        )
      rescue Compression::SafeZipReader::TooManyEntriesError
        return(
          render json: failed_json.merge(errors: [I18n.t("emoji.import.too_many_entries")]),
                 status: :unprocessable_entity
        )
      rescue Compression::SafeZipReader::EntryTooLargeError
        return(
          render json: failed_json.merge(errors: [I18n.t("emoji.import.file_too_large")]),
                 status: :unprocessable_entity
        )
      end

      token = SecureRandom.hex
      manifest = { rows: rows, upload_map: upload_map }
      Discourse.redis.setex(import_preview_key(token), IMPORT_PREVIEW_TTL, manifest.to_json)

      render json: { token: token, rows: rows }
    end
  end

  def import_confirm
    token = params.require(:token)
    resolutions = params[:resolutions] || {}

    manifest_json = Discourse.redis.get(import_preview_key(token))
    if manifest_json.blank?
      return(
        render json: failed_json.merge(errors: [I18n.t("emoji.import.session_expired")]),
               status: :unprocessable_entity
      )
    end

    manifest = JSON.parse(manifest_json, symbolize_names: true)
    rows = manifest[:rows]
    upload_map = manifest[:upload_map]

    created = 0
    updated = 0
    skipped = 0

    actionable_names =
      rows
        .map { |r| r.transform_keys(&:to_s) }
        .reject { |r| %w[invalid identical].include?(r["category"]) }
        .filter_map { |r| r["name"] if (resolutions[r["name"].to_s] || "incoming") != "keep" }
    existing_by_name = CustomEmoji.where(name: actionable_names).index_by(&:name)

    ActiveRecord::Base.transaction do
      rows.each do |row|
        row = row.transform_keys(&:to_s)
        name = row["name"]
        group = row["group"].presence
        filename = row["filename"]
        category = row["category"]

        next if category == "invalid"

        if category == "identical"
          skipped += 1
          next
        end

        resolution = resolutions[name.to_s] || "incoming"
        next if resolution == "keep"

        upload_id = upload_map[filename.to_sym] || upload_map[filename.to_s]
        upload = Upload.find_by(id: upload_id)
        next if upload.nil?

        existing = existing_by_name[name]

        if existing
          existing.update!(upload: upload, group: group)
        else
          custom_emoji =
            CustomEmoji.new(name: name, upload: upload, group: group, user: current_user)
          custom_emoji.save!
          StaffActionLogger.new(current_user).log_custom_emoji_create(name, group: group)
          created += 1
        end

        if existing &&
             (
               category == "conflict_group" || category == "conflict_image" ||
                 category == "conflict_both"
             )
          StaffActionLogger.new(current_user).log_custom_emoji_create(name, group: group)
          updated += 1
        end
      end

      Emoji.clear_cache
    end

    Discourse.redis.del(import_preview_key(token))

    render json: { created: created, updated: updated, skipped: skipped }
  rescue ActiveRecord::RecordInvalid => e
    render json: failed_json.merge(errors: [e.message]), status: :unprocessable_entity
  end

  def destroy
    name = params.require(:id)

    # NOTE: the upload will automatically be removed by the 'clean_up_uploads' job
    emoji = CustomEmoji.find_by(name: name)

    if emoji.present?
      StaffActionLogger.new(current_user).log_custom_emoji_destroy(name)
      emoji.destroy!
    end

    Emoji.clear_cache

    Jobs.enqueue(:rebake_custom_emoji_posts, name: name)

    render json: success_json
  end

  private

  def import_preview_key(token)
    "emoji_import_preview:#{current_user.id}:#{token}"
  end

  def validate_import_row(name, group, filename, filenames_seen)
    errors = []
    errors << I18n.t("emoji.import.validation.missing_name") if name.blank?
    errors << I18n.t("emoji.import.validation.missing_filename") if filename.blank?

    if name.present?
      sanitized = Emoji.sanitize_emoji_name(name)
      errors << I18n.t("emoji.import.validation.invalid_name") if sanitized.blank?
    end

    if group.present? && group.length > 20
      errors << I18n.t("emoji.import.validation.group_too_long")
    end

    if filename.present?
      ext = File.extname(filename).delete(".").downcase
      if SUPPORTED_EXTENSIONS.exclude?(ext)
        errors << I18n.t("emoji.import.validation.unsupported_extension", ext: ext)
      end
      errors << I18n.t("emoji.import.validation.duplicate_filename") if filenames_seen[filename]
    end

    errors
  end

  def classify_import_row(name, group, upload, existing = nil)
    existing ||= CustomEmoji.find_by(name: name)
    return "new", nil unless existing

    existing_url = existing.upload&.url
    existing_group = existing.group.presence
    existing_group = nil if existing_group == "default"
    group_changed = existing_group != group
    display_existing_group = existing_group || "default"
    image_changed = existing.upload&.sha1 != upload.sha1

    category =
      if group_changed && image_changed
        "conflict_both"
      elsif image_changed
        "conflict_image"
      elsif group_changed
        "conflict_group"
      else
        "identical"
      end

    [category, existing_url, display_existing_group]
  end
end
