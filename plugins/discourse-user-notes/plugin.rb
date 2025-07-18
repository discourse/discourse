# frozen_string_literal: true

# name: discourse-user-notes
# about: Provides staff the ability to share notes with other staff about a user.
# meta_topic_id: 41026
# version: 0.0.2
# authors: Robin Ward
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-user-notes

enabled_site_setting :user_notes_enabled

register_asset "stylesheets/user_notes.scss"

register_svg_icon "pen-to-square"

after_initialize do
  require_dependency "user"

  module ::DiscourseUserNotes
    PLUGIN_NAME = "discourse-user-notes"
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
  end

  require_relative "app/serializers/user_note_serializer.rb"
  require_relative "app/controllers/discourse_user_notes/user_notes_controller.rb"

  Discourse::Application.routes.append { mount ::DiscourseUserNotes::Engine, at: "/user_notes" }

  DiscourseUserNotes::Engine.routes.draw do
    get "/" => "user_notes#index"
    post "/" => "user_notes#create"
    delete "/:id" => "user_notes#destroy"
  end

  allow_staff_user_custom_field(DiscourseUserNotes::COUNT_FIELD)

  add_to_class(Guardian, :can_delete_user_notes?) do
    (SiteSetting.user_notes_moderators_delete? && user.staff?) || user.admin?
  end

  add_to_serializer(:admin_detailed_user, :user_notes_count) do
    object.custom_fields && object.custom_fields["user_notes_count"].to_i
  end

  add_model_callback(UserWarning, :after_commit, on: :create) do
    user = User.find_by_id(self.user_id)
    created_by_user = User.find_by_id(self.created_by_id)
    warning_topic = Topic.find_by_id(self.topic_id)
    raw_note =
      I18n.with_locale(SiteSetting.default_locale) do
        I18n.t(
          "user_notes.official_warning",
          username: created_by_user.username,
          warning_link: "[#{warning_topic.title}](#{warning_topic.url})",
        )
      end
    ::DiscourseUserNotes.add_note(
      user,
      raw_note,
      Discourse::SYSTEM_USER_ID,
      topic_id: self.topic_id,
    )
  end

  add_report("user_notes") do |report|
    report.modes = [:table]

    report.data = []

    report.labels = [
      {
        type: :user,
        properties: {
          username: :username,
          id: :user_id,
          avatar: :user_avatar_template,
        },
        title: I18n.t("reports.user_notes.labels.user"),
      },
      {
        type: :user,
        properties: {
          username: :moderator_username,
          id: :moderator_id,
          avatar: :moderator_avatar_template,
        },
        title: I18n.t("reports.user_notes.labels.moderator"),
      },
      { type: :text, property: :note, title: I18n.t("reports.user_notes.labels.note") },
    ]

    values = []
    values =
      PluginStoreRow
        .where(plugin_name: "user_notes")
        .where("value::json->0->>'created_at'>=?", report.start_date)
        .where("value::json->0->>'created_at'<=?", report.end_date)
        .pluck(:value)

    values.each do |value|
      notes = JSON.parse(value)
      notes.each do |note|
        data = {}
        created_at = Time.parse(note["created_at"])
        user = User.find_by(id: note["user_id"])
        moderator = User.find_by(id: note["created_by"])

        if user && moderator
          data[:created_at] = created_at
          data[:user_id] = user.id
          data[:username] = user.username_lower
          data[:user_avatar_template] = User.avatar_template(
            user.username_lower,
            user.uploaded_avatar_id,
          )
          data[:moderator_id] = moderator.id
          data[:moderator_username] = moderator.username_lower
          data[:moderator_avatar_template] = User.avatar_template(
            moderator.username_lower,
            moderator.uploaded_avatar_id,
          )
          data[:note] = note["raw"]

          report.data << data
        end
      end
    end
  end
end
