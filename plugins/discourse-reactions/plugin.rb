# frozen_string_literal: true

# name: discourse-reactions
# about: Allows users to react to a post with emojis.
# meta_topic_id: 183261
# version: 0.5
# author: Ahmed Gagan, Rafael dos Santos Silva, Kris Aubuchon, Joffrey Jaffeux, Kris Kotlarek, Jordan Vidrine
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-reactions

enabled_site_setting :discourse_reactions_enabled

register_asset "stylesheets/common/discourse-reactions.scss"
register_asset "stylesheets/desktop/discourse-reactions.scss", :desktop
register_asset "stylesheets/mobile/discourse-reactions.scss", :mobile

register_svg_icon "star"
register_svg_icon "far-star"

require_relative "lib/reaction_for_like_site_setting_enum"
require_relative "lib/reactions_excluded_from_like_site_setting_validator"

module ::DiscourseReactions
  PLUGIN_NAME = "discourse-reactions"
end

require_relative "lib/discourse_reactions/engine"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins/discourse-reactions/db/fixtures").to_s

  %w[
    app/controllers/discourse_reactions/custom_reactions_controller.rb
    app/models/discourse_reactions/reaction_user.rb
    app/models/discourse_reactions/reaction.rb
    app/serializers/reaction_serializer.rb
    app/serializers/user_reaction_serializer.rb
    app/services/discourse_reactions/reaction_manager.rb
    app/services/discourse_reactions/reaction_notification.rb
    app/services/discourse_reactions/reaction_like_synchronizer.rb
    lib/discourse_reactions/guardian_extension.rb
    lib/discourse_reactions/notification_extension.rb
    lib/discourse_reactions/post_alerter_extension.rb
    lib/discourse_reactions/post_extension.rb
    lib/discourse_reactions/post_action_extension.rb
    lib/discourse_reactions/reactions_serializer_helpers.rb
    lib/discourse_reactions/posts_reaction_loader.rb
    lib/discourse_reactions/topic_view_serializer_extension.rb
    lib/discourse_reactions/topic_view_posts_serializer_extension.rb
    lib/discourse_reactions/migration_report.rb
    lib/discourse_reactions/post_reactions_query.rb
    app/jobs/regular/discourse_reactions/like_synchronizer.rb
    app/jobs/scheduled/discourse_reactions/scheduled_like_synchronizer.rb
  ].each { |path| require_relative path }

  reloadable_patch do |plugin|
    Post.prepend DiscourseReactions::PostExtension
    PostAction.prepend DiscourseReactions::PostActionExtension
    TopicViewSerializer.prepend DiscourseReactions::TopicViewSerializerExtension
    TopicViewPostsSerializer.prepend DiscourseReactions::TopicViewPostsSerializerExtension
    PostAlerter.prepend DiscourseReactions::PostAlerterExtension
    Guardian.prepend DiscourseReactions::GuardianExtension
    Notification.singleton_class.prepend DiscourseReactions::NotificationExtension
  end

  register_anonymous_action("react_to_post") do |user, params|
    post = Post.find_by(id: params["post_id"])
    next if !post || !user.guardian.can_see?(post)
    reaction_value = params["reaction"].to_s
    next if !DiscourseReactions::Reaction.valid?(reaction_value)
    DiscourseReactions::ReactionManager.new(reaction_value:, user:, post:).toggle!
  end

  Discourse::Application.routes.append { mount DiscourseReactions::Engine, at: "/" }

  TopicView.on_preload do |topic_view|
    next unless SiteSetting.discourse_reactions_enabled

    posts = topic_view.posts
    next if posts.blank?

    preloaded =
      DiscourseReactions::ReactionsSerializerHelpers.preload_post_reactions(
        posts,
        topic_view.guardian.user,
      )

    topic_view.set_preloaded_post_data(:reactions, preloaded[:reactions])
    topic_view.set_preloaded_post_data(:reaction_users_count, preloaded[:reaction_users_count])
  end

  TopicList.on_preload do |topics, topic_list|
    next unless SiteSetting.discourse_reactions_enabled
    next if topics.blank?

    should_preload =
      if topic_list.filter == :suggested
        DiscoursePluginRegistry.apply_modifier(
          :include_discourse_reactions_data_on_suggested_topics,
          false,
          topic_list.current_user,
        )
      else
        DiscoursePluginRegistry.apply_modifier(
          :include_discourse_reactions_data_on_topic_list,
          false,
          topic_list.current_user,
        )
      end

    next unless should_preload

    posts = topics.filter_map { |topic| topic.first_post if topic.association(:first_post).loaded? }
    DiscourseReactions::ReactionsSerializerHelpers.preload_post_reactions(
      posts,
      topic_list.current_user,
    )
  end

  add_to_serializer(:post, :reactions) do
    map = topic_view&.preloaded_post_data(:reactions)
    if map && map.key?(object.id)
      map[object.id]
    else
      DiscourseReactions::ReactionsSerializerHelpers.reactions_for_post(object, scope)
    end
  end

  add_to_serializer(:post, :current_user_reaction) do
    DiscourseReactions::ReactionsSerializerHelpers.current_user_reaction_for_post(object, scope)
  end

  add_to_serializer(:post, :reaction_users_count) do
    map = topic_view&.preloaded_post_data(:reaction_users_count)
    if map && map.key?(object.id)
      map[object.id].to_i
    else
      DiscourseReactions::ReactionsSerializerHelpers.reaction_users_count_for_post(
        object,
        scope,
      ).to_i
    end
  end

  add_to_serializer(:post, :current_user_used_main_reaction) do
    DiscourseReactions::ReactionsSerializerHelpers.current_user_used_main_reaction_for_post(
      object,
      scope,
    )
  end

  add_to_serializer(
    :topic_list_item,
    :op_reactions_data,
    include_condition: -> do
      object.association(:first_post).loaded? &&
        DiscoursePluginRegistry.apply_modifier(
          :include_discourse_reactions_data_on_topic_list,
          false,
          scope.user,
        )
    end,
  ) { DiscourseReactions::ReactionsSerializerHelpers.op_reactions_data_for_topic(object, scope) }

  add_to_serializer(
    :suggested_topic,
    :op_reactions_data,
    include_condition: -> do
      object.association(:first_post).loaded? &&
        DiscoursePluginRegistry.apply_modifier(
          :include_discourse_reactions_data_on_suggested_topics,
          false,
          scope.user,
        )
    end,
  ) { DiscourseReactions::ReactionsSerializerHelpers.op_reactions_data_for_topic(object, scope) }

  add_to_serializer(:topic_view, :valid_reactions) { DiscourseReactions::Reaction.valid_reactions }

  add_model_callback(User, :before_destroy) do
    DiscourseReactions::ReactionUser.where(user_id: id).delete_all
  end

  add_report("reactions") do |report|
    main_id = DiscourseReactions::Reaction.main_reaction_id

    report.icon = "discourse-emojis"
    report.modes = [:table]

    report.data = []

    report.labels = [
      { type: :date, property: :day, title: I18n.t("reports.reactions.labels.day") },
      {
        type: :number,
        property: :like_count,
        title: main_id,
        html_title: PrettyText.unescape_emoji(CGI.escapeHTML(":#{main_id}:")),
      },
    ]

    reactions = SiteSetting.discourse_reactions_enabled_reactions.split("|") - [main_id]

    reactions.each do |reaction|
      report.labels << {
        type: :number,
        property: "#{reaction}_count",
        title: reaction,
        html_title: PrettyText.unescape_emoji(CGI.escapeHTML(":#{reaction}:")),
      }
    end

    reactions_results =
      DB.query(<<~SQL, start_date: report.start_date.to_date, end_date: report.end_date.to_date)
        SELECT
          reactions.reaction_value,
          count(reaction_users.id) as reactions_count,
          date_trunc('day', reaction_users.created_at)::date as day
        FROM discourse_reactions_reactions as reactions
        LEFT OUTER JOIN discourse_reactions_reaction_users as reaction_users on reactions.id = reaction_users.reaction_id
        WHERE reactions.reaction_users_count IS NOT NULL
          AND reaction_users.created_at::DATE >= :start_date::DATE AND reaction_users.created_at::DATE <= :end_date::DATE
        GROUP BY reactions.reaction_value, day
      SQL

    likes_results =
      DB.query(
        <<~SQL,
          SELECT
            count(post_actions.id) as likes_count,
            date_trunc('day', post_actions.created_at)::date as day
          FROM post_actions as post_actions
          WHERE post_actions.created_at::DATE >= :start_date::DATE AND post_actions.created_at::DATE <= :end_date::DATE
          AND #{DiscourseReactions::PostActionExtension.filter_reaction_likes_sql}
          GROUP BY day
        SQL
        start_date: report.start_date.to_date,
        end_date: report.end_date.to_date,
        like: PostActionType::LIKE_POST_ACTION_ID,
        valid_reactions: DiscourseReactions::Reaction.valid_reactions.to_a,
      )

    (report.start_date.to_date..report.end_date.to_date).each do |date|
      data = { day: date }

      like_count = 0
      like_reaction_count = 0
      likes_results.select { |r| r.day == date }.each { |result| like_count += result.likes_count }

      reactions_results
        .select { |r| r.day == date }
        .each do |result|
          if result.reaction_value == main_id
            like_reaction_count += result.reactions_count
          else
            data["#{result.reaction_value}_count"] ||= 0
            data["#{result.reaction_value}_count"] += result.reactions_count
          end
        end

      data[:like_count] = like_reaction_count + like_count

      report.data << data
    end
  end

  field_key = "display_username"
  consolidated_reactions =
    Notifications::ConsolidateNotifications
      .new(
        from: Notification.types[:reaction],
        to: Notification.types[:reaction],
        threshold: -> { SiteSetting.notification_consolidation_threshold },
        consolidation_window: SiteSetting.likes_notification_consolidation_window_mins.minutes,
        unconsolidated_query_blk:
          Proc.new do |notifications, data|
            notifications.where(
              "data::json ->> 'username2' IS NULL AND data::json ->> 'consolidated' IS NULL",
            ).where("data::json ->> '#{field_key}' = ?", data[field_key.to_sym].to_s)
          end,
        consolidated_query_blk:
          Proc.new do |notifications, data|
            notifications.where("(data::json ->> 'consolidated')::bool").where(
              "data::json ->> '#{field_key}' = ?",
              data[field_key.to_sym].to_s,
            )
          end,
      )
      .set_mutations(
        set_data_blk:
          Proc.new do |notification|
            data = notification.data_hash
            data.merge(
              username: data[:display_username],
              name: data[:display_name],
              consolidated: true,
            )
          end,
      )
      .set_precondition(precondition_blk: Proc.new { |data| data[:username2].blank? })

  consolidated_reactions.before_consolidation_callbacks(
    before_consolidation_blk:
      Proc.new do |notifications, data|
        new_icon = data[:reaction_icon]

        if new_icon
          icons = notifications.pluck("data::json ->> 'reaction_icon'")

          data.delete(:reaction_icon) if icons.any? { |i| i != new_icon }
        end
      end,
    before_update_blk:
      Proc.new do |consolidated, updated_data, notification|
        if consolidated.data_hash[:reaction_icon] != notification.data_hash[:reaction_icon]
          updated_data.delete(:reaction_icon)
        end
      end,
  )

  reacted_by_two_users =
    Notifications::DeletePreviousNotifications
      .new(
        type: Notification.types[:reaction],
        previous_query_blk:
          Proc.new do |notifications, data|
            notifications.where(id: data[:previous_notification_id])
          end,
      )
      .set_mutations(
        set_data_blk:
          Proc.new do |notification|
            existing_notification_of_same_type =
              Notification
                .where(user: notification.user)
                .order("notifications.id DESC")
                .where(topic_id: notification.topic_id, post_number: notification.post_number)
                .where(notification_type: notification.notification_type)
                .where("created_at > ?", 1.day.ago)
                .first

            data = notification.data_hash
            if existing_notification_of_same_type
              same_type_data = existing_notification_of_same_type.data_hash

              new_data =
                data.merge(
                  previous_notification_id: existing_notification_of_same_type.id,
                  username2: same_type_data[:display_username],
                  name2: same_type_data[:display_name],
                  count: (same_type_data[:count] || 1).to_i + 1,
                )

              new_data
            else
              data
            end
          end,
      )
      .set_precondition(
        precondition_blk:
          Proc.new do |data, notification|
            always_freq = UserOption.like_notification_frequency_type[:always]

            notification.user&.user_option&.like_notification_frequency == always_freq &&
              data[:previous_notification_id].present?
          end,
      )

  register_notification_consolidation_plan(reacted_by_two_users)
  register_notification_consolidation_plan(consolidated_reactions)

  # Filter out Likes that are also Reactions, for the user likes-received page.
  register_modifier(:user_action_stream_builder) do |builder|
    builder.left_join(<<~SQL)
      discourse_reactions_reaction_users ON discourse_reactions_reaction_users.post_id = a.target_post_id
      AND discourse_reactions_reaction_users.user_id = a.acting_user_id
    SQL
    builder.where("discourse_reactions_reaction_users.id IS NULL")
  end

  # Filter out the users who Liked as well as Reacted to the post, for the
  # user avatars that show beneath the post when you click the "show more actions"
  # [...] button.
  register_modifier(:post_action_users_list) do |query, post|
    where_clause = <<~SQL
      post_actions.id NOT IN (
        SELECT post_actions.id
        FROM post_actions
        INNER JOIN discourse_reactions_reaction_users ON discourse_reactions_reaction_users.post_id = post_actions.post_id
          AND discourse_reactions_reaction_users.user_id = post_actions.user_id
        WHERE post_actions.post_id = #{post.id}
      )
    SQL

    query.where(where_clause)
  end

  on(:first_post_moved) do |target_post, original_post|
    id_map = {}
    ActiveRecord::Base.transaction do
      reactions = DiscourseReactions::Reaction.where(post_id: original_post.id)
      next if !reactions.any?

      reactions_attributes =
        reactions.map { |reaction| reaction.attributes.except("id").merge(post_id: target_post.id) }

      DiscourseReactions::Reaction
        .insert_all(reactions_attributes)
        .each_with_index { |entry, index| id_map[reactions[index].id] = entry["id"] }

      reaction_users = DiscourseReactions::ReactionUser.where(post_id: original_post.id)
      next if !reaction_users.any?

      reaction_users_attributes =
        reaction_users.map do |reaction_user|
          reaction_user
            .attributes
            .except("id")
            .merge(post_id: target_post.id, reaction_id: id_map[reaction_user.reaction_id])
        end

      DiscourseReactions::ReactionUser.insert_all(reaction_users_attributes)
    end
  end

  on(:site_setting_changed) do |name, old_value, new_value|
    if name == :discourse_reactions_excluded_from_like &&
         SiteSetting.discourse_reactions_like_sync_enabled
      ::Jobs.cancel_scheduled_job(Jobs::DiscourseReactions::LikeSynchronizer)
      ::Jobs.enqueue_at(5.minutes.from_now, Jobs::DiscourseReactions::LikeSynchronizer)
    end
  end
end
