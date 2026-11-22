# frozen_string_literal: true

module DiscourseUserNotes
  COUNT_FIELD = "user_notes_count"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseUserNotes
  end

  def self.key_for(user_id)
    "notes:#{user_id}"
  end

  def self.notes_for(user_id)
    PluginStore.get("user_notes", key_for(user_id)) || []
  end

  def self.add_note(user, raw, created_by, opts = nil)
    opts ||= {}

    notes = notes_for(user.id)
    record = {
      id: SecureRandom.hex(16),
      user_id: user.id,
      raw: raw,
      created_by: created_by,
      created_at: Time.now,
    }.merge(opts)

    notes << record
    ::PluginStore.set("user_notes", key_for(user.id), notes)

    user.custom_fields[DiscourseUserNotes::COUNT_FIELD] = notes.size
    user.save_custom_fields
    enqueue_staff_notification(user.id, record[:id])

    record
  end

  def self.remove_note(user, note_id)
    notes = notes_for(user.id)
    notes.reject! { |n| n[:id] == note_id }

    if notes.size > 0
      ::PluginStore.set("user_notes", key_for(user.id), notes)
    else
      ::PluginStore.remove("user_notes", key_for(user.id))
    end
    user.custom_fields[DiscourseUserNotes::COUNT_FIELD] = notes.size
    user.save_custom_fields
  end

  def self.enqueue_staff_notification(user_id, note_id)
    return if !SiteSetting.user_notes_enabled? || SiteSetting.user_notes_notification_groups.blank?

    ActiveRecord.after_all_transactions_commit do
      Jobs.enqueue(:notify_staff_user_note, user_id:, note_id:)
    end
  end
  private_class_method :enqueue_staff_notification
end
