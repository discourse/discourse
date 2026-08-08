# frozen_string_literal: true

class CustomEmoji::Action::ApplyImportRows < Service::ActionBase
  KEEP_RESOLUTION = "keep"

  option :rows
  option :resolutions
  option :acting_user

  def call
    report = { created: 0, updated: 0, skipped: 0 }

    rows.each do |row|
      next if row.invalid?

      if row.identical?
        report[:skipped] += 1
        next
      end

      next if keep_existing?(row)

      upload = uploads[row.upload_id]
      next if upload.nil?

      if (existing = existing_emojis[row.name])
        existing.update!(upload:, group: row.group)
        report[:updated] += 1
      else
        CustomEmoji.create!(name: row.name, group: row.group, upload:, user: acting_user)
        report[:created] += 1
      end
      log_change(row)
    end

    report
  end

  private

  def existing_emojis
    @existing_emojis ||= CustomEmoji.where(name: rows_to_apply.map(&:name)).index_by(&:name)
  end

  def uploads
    @uploads ||= Upload.where(id: rows_to_apply.map(&:upload_id)).index_by(&:id)
  end

  def rows_to_apply
    @rows_to_apply ||= rows.reject { |row| row.invalid? || row.identical? || keep_existing?(row) }
  end

  def keep_existing?(row)
    resolutions_by_name[row.name] == KEEP_RESOLUTION
  end

  # resolution keys may arrive as strings or symbols depending on the caller
  def resolutions_by_name
    @resolutions_by_name ||= resolutions.to_h.transform_keys(&:to_s)
  end

  def log_change(row)
    StaffActionLogger.new(acting_user).log_custom_emoji_create(row.name, group: row.group)
  end
end
