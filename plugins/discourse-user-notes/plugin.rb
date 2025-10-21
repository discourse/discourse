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

module ::DiscourseUserNotes
  PLUGIN_NAME = "discourse-user-notes"
end

require_relative "lib/discourse_user_notes/engine"

after_initialize do
  require_dependency "user"

  require_relative "app/serializers/user_note_serializer"
  require_relative "app/controllers/discourse_user_notes/user_notes_controller"

  Discourse::Application.routes.append { mount DiscourseUserNotes::Engine, at: "/user_notes" }

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
    DiscourseUserNotes.add_note(user, raw_note, Discourse::SYSTEM_USER_ID, topic_id: self.topic_id)

    # Fire event after note is created for other plugins to hook into
    DiscourseEvent.trigger(:user_warning_created, self)
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
