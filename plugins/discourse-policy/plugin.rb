# frozen_string_literal: true

# name: discourse-policy
# about: Gives the ability to confirm your users have seen or done something, with optional reminders.
# meta_topic_id: 88557
# version: 0.1.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-policy

register_asset "stylesheets/common/discourse-policy.scss"
register_asset "stylesheets/common/discourse-policy-builder.scss"

register_svg_icon "user-check"
register_svg_icon "file-signature"

enabled_site_setting :policy_enabled

module ::DiscoursePolicy
  PLUGIN_NAME = "discourse-policy"
end

require_relative "lib/discourse_policy/engine"

after_initialize do
  require_relative "app/controllers/discourse_policy/policy_controller"
  require_relative "app/models/policy_user"
  require_relative "app/models/post_policy_group"
  require_relative "app/models/post_policy"
  require_relative "jobs/scheduled/check_policy"
  require_relative "lib/email_controller_helper/policy_email_unsubscriber"
  require_relative "lib/extensions/post_extension"
  require_relative "lib/extensions/post_serializer_extension"
  require_relative "lib/extensions/user_notifications_extension"
  require_relative "lib/extensions/user_option_extension"
  require_relative "lib/policy_mailer"

  Discourse::Application.routes.append { mount DiscoursePolicy::Engine, at: "/policy" }

  Post.prepend DiscoursePolicy::PostExtension
  PostSerializer.prepend DiscoursePolicy::PostSerializerExtension
  UserNotifications.prepend DiscoursePolicy::UserNotificationsExtension
  UserOption.prepend DiscoursePolicy::UserOptionExtension

  UserUpdater::OPTION_ATTR.push(:policy_email_frequency)

  UserNotifications.append_view_path(File.expand_path("../app/views", __FILE__))

  add_to_serializer(:user_option, :policy_email_frequency) { object.policy_email_frequency }

  register_email_unsubscriber("policy_email", EmailControllerHelper::PolicyEmailUnsubscriber)

  TopicView.default_post_custom_fields << DiscoursePolicy::HAS_POLICY

  on(:post_process_cooked) do |doc, post|
    has_group = false

    if !SiteSetting.policy_restrict_to_staff_posts || post&.user&.staff?
      if policy = doc.search(".policy")&.first
        post_policy = post.post_policy || post.build_post_policy

        group_names = []

        if group = policy["data-group"]
          group_names << group
        end

        if groups = policy["data-groups"]
          group_names.concat(groups.split(","))
        end

        new_group_ids = Group.where("name in (?)", group_names).pluck(:id)

        has_group = true if new_group_ids.length > 0

        existing_ids = post_policy.post_policy_groups.pluck(:group_id)

        missing = (new_group_ids - existing_ids)

        new_relations = []

        post_policy.post_policy_groups.each do |relation|
          new_relations << relation if new_group_ids.include?(relation.group_id)
        end

        missing.each do |id|
          new_relations << PostPolicyGroup.new(post_policy_id: post_policy.id, group_id: id)
        end

        post_policy.post_policy_groups = new_relations

        renew_days = policy["data-renew"]
        if (renew_days.to_i) > 0 || PostPolicy.renew_intervals.keys.include?(renew_days)
          post_policy.renew_days =
            PostPolicy.renew_intervals.keys.include?(renew_days) ? nil : renew_days
          post_policy.renew_interval = post_policy.renew_days.present? ? nil : renew_days

          post_policy.renew_start = nil

          if (renew_start = policy["data-renew-start"])
            begin
              renew_start = Date.parse(renew_start)
              post_policy.renew_start = renew_start
              if !post_policy.next_renew_at || post_policy.next_renew_at < renew_start
                post_policy.next_renew_at = renew_start
              end
            rescue ArgumentError
              # already nil
            end
          else
            post_policy.next_renew_at = nil
          end
        else
          post_policy.renew_days = nil
          post_policy.renew_start = nil
          post_policy.next_renew_at = nil
        end

        if version = policy["data-version"]
          old_version = post_policy.version || "1"
          if version != old_version
            post_policy.version = version

            if post_policy.add_users_to_group.present?
              previously_accepted_users = post_policy.accepted_policy_users

              Group.find_by(id: post_policy.add_users_to_group)&.remove(previously_accepted_users)
            end
          end
        end

        if reminder = policy["data-reminder"]
          post_policy.reminder = reminder
          post_policy.last_reminded_at ||= Time.zone.now
        end

        post_policy.private = policy["data-private"] == "true"

        if policy["data-add-users-to-group"].present?
          post_policy.add_users_to_group = Group.find_by_name(policy["data-add-users-to-group"])&.id
        end

        if has_group
          if !post.custom_fields[DiscoursePolicy::HAS_POLICY]
            post.custom_fields[DiscoursePolicy::HAS_POLICY] = true
            post.save_custom_fields
          end
          post_policy.save!
        end
      end
    end

    if !has_group && (post.custom_fields[DiscoursePolicy::HAS_POLICY] || !post_policy&.new_record?)
      post.custom_fields.delete(DiscoursePolicy::HAS_POLICY)
      post.save_custom_fields
      PostPolicy.where(post_id: post.id).destroy_all
    end
  end

  add_report("unaccepted-policies") do |report|
    report.modes = [:table]

    report.labels = [
      { property: :topic_id, title: I18n.t("reports.unaccepted-policies.labels.topic_id") },
      { property: :user_id, title: I18n.t("reports.unaccepted-policies.labels.user_id") },
    ]

    results = DB.query(<<~SQL)
      SELECT distinct t.id AS topic_id, gu.user_id AS user_id
      FROM post_policies pp
      JOIN post_policy_groups pg on pg.post_policy_id = pp.id
      JOIN posts p ON p.id = pp.post_id AND p.deleted_at is null
      JOIN topics t ON t.id = p.topic_id AND t.deleted_at is null
      JOIN group_users gu ON gu.group_id = pg.group_id
      LEFT JOIN policy_users pu ON
        pu.user_id = gu.user_id AND
        pu.post_policy_id = pp.id AND
        pu.accepted_at IS NOT NULL AND
        pu.revoked_at IS NULL AND
        (pu.expired_at IS NULL OR pu.expired_at < pu.accepted_at) AND
        ((pu.version IS NULL AND pp.version IS NULL) OR
        (pp.version IS NOT NULL AND pu.version IS NOT NULL AND pu.version = pp.version))
      WHERE pu.id IS NULL
    SQL

    report.data = []
    results.each do |row|
      data = {}
      data[:user_id] = row.user_id
      data[:topic_id] = row.topic_id
      report.data << data
    end
  end
end
