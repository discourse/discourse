# frozen_string_literal: true

# name: discourse-reactions
# about: Allows users to react to a post with emojis.
# meta_topic_id: 183261
# version: 0.5
# author: Ahmed Gagan, Rafael dos Santos Silva, Kris Aubuchon, Joffrey Jaffeux, Kris Kotlarek, Jordan Vidrine
# url: https://github.com/discourse/discourse-reactions

enabled_site_setting :discourse_reactions_enabled

register_asset "stylesheets/common/discourse-reactions.scss"
register_asset "stylesheets/desktop/discourse-reactions.scss", :desktop
register_asset "stylesheets/mobile/discourse-reactions.scss", :mobile

register_svg_icon "star"
register_svg_icon "far-star"

require_relative "lib/reaction_for_like_site_setting_enum.rb"
require_relative "lib/reactions_excluded_from_like_site_setting_validator.rb"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-reactions", "db", "fixtures").to_s

  module ::DiscourseReactions
    PLUGIN_NAME = "discourse-reactions"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseReactions
    end
  end

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
    lib/discourse_reactions/posts_reaction_loader.rb
    lib/discourse_reactions/topic_view_serializer_extension.rb
    lib/discourse_reactions/topic_view_posts_serializer_extension.rb
    lib/discourse_reactions/migration_report.rb
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

  Discourse::Application.routes.append { mount ::DiscourseReactions::Engine, at: "/" }

  DiscourseReactions::Engine.routes.draw do
    get "/discourse-reactions/custom-reactions" => "custom_reactions#index",
        :constraints => {
          format: :json,
        }
    put "/discourse-reactions/posts/:post_id/custom-reactions/:reaction/toggle" =>
          "custom_reactions#toggle",
        :constraints => {
          format: :json,
        }
    get "/discourse-reactions/posts/reactions" => "custom_reactions#reactions_given",
        :as => "reactions_given"
    get "/discourse-reactions/posts/reactions-received" => "custom_reactions#reactions_received",
        :as => "reactions_received"
    get "/discourse-reactions/posts/:id/reactions-users" => "custom_reactions#post_reactions_users",
        :as => "post_reactions_users"
  end

  add_to_serializer(:post, :reactions) do
    reactions = []
    reaction_users_counting_as_like = Set.new

    object
      .emoji_reactions
      .select { |reaction| reaction[:reaction_users_count] }
      .each do |reaction|
        reactions << {
          id: reaction.reaction_value,
          type: reaction.reaction_type.to_sym,
          count: reaction.reaction_users_count,
        }

        # NOTE: It does not matter if the reaction is currently an enabled one,
        # we need to handle historical data here too so we don't see double-ups in the UI.
        if !DiscourseReactions::Reaction.reactions_excluded_from_like.include?(
             reaction.reaction_value,
           ) && reaction.reaction_value != DiscourseReactions::Reaction.main_reaction_id
          reaction_users_counting_as_like.merge(reaction.reaction_users.pluck(:user_id))
        end
      end

    likes =
      object.post_actions.reject do |post_action|
        # Get rid of any PostAction records that match up to a ReactionUser
        # that is NOT main_reaction_id and is NOT excluded, otherwise we double
        # up on the count/reaction shown in the UI.
        next true if reaction_users_counting_as_like.include?(post_action.user_id)

        # Also get rid of any PostAction records that match up to a ReactionUser
        # that is now the main_reaction_id and has historical data.
        object
          .post_actions_with_reaction_users
          &.dig(post_action.id)
          &.reaction_user
          &.reaction
          &.reaction_value == DiscourseReactions::Reaction.main_reaction_id
      end

    # Likes will only be blank if there are only reactions where the reaction is in
    # discourse_reactions_excluded_from_like. All other reactions will have a `PostAction` record.
    return reactions.sort_by { |reaction| [-reaction[:count].to_i, reaction[:id]] } if likes.blank?

    # Reactions using main_reaction_id only have a `PostAction` record,
    # not any `ReactionUser` records, as long as the main_reaction_id was never
    # changed -- if it was then we could have a ReactionUser as well.
    reaction_likes, reactions =
      reactions.partition { |r| r[:id] == DiscourseReactions::Reaction.main_reaction_id }

    reactions << {
      id: DiscourseReactions::Reaction.main_reaction_id,
      type: :emoji,
      count: likes.size + reaction_likes.sum { |r| r[:count] },
    }

    reactions.sort_by { |reaction| [-reaction[:count].to_i, reaction[:id]] }
  end

  add_to_serializer(:post, :current_user_reaction) do
    return nil if scope.is_anonymous?

    object.emoji_reactions.each do |reaction|
      reaction_user = reaction.reaction_users.find { |ru| ru.user_id == scope.user.id }
      next if reaction_user.blank?

      if reaction.reaction_users_count
        return(
          {
            id: reaction.reaction_value,
            type: reaction.reaction_type.to_sym,
            can_undo: reaction_user.can_undo?,
          }
        )
      end
    end

    # Any PostAction Like that doesn't have a matching ReactionUser record
    # will count as the main_reaction_id.
    like =
      object.post_actions.find do |post_action|
        post_action.post_action_type_id == PostActionType::LIKE_POST_ACTION_ID &&
          !post_action.trashed? && post_action.user_id == scope.user.id
      end

    return nil if like.blank?

    {
      id: DiscourseReactions::Reaction.main_reaction_id,
      type: :emoji,
      can_undo: scope.can_delete_post_action?(like),
    }
  end

  add_to_serializer(:post, :reaction_users_count) do
    return object.reaction_users_count unless object.reaction_users_count.nil?
    TopicViewSerializer.posts_reaction_users_count(object.id)[object.id]
  end

  add_to_serializer(:post, :current_user_used_main_reaction) do
    return false if scope.is_anonymous?

    like_post_action =
      object.post_actions.find do |post_action|
        post_action.post_action_type_id == PostActionType::LIKE_POST_ACTION_ID &&
          post_action.user_id == scope.user.id && !post_action.trashed?
      end

    has_matching_reaction_user =
      object.emoji_reactions.any? do |reaction|
        DiscourseReactions::Reaction.reactions_counting_as_like.include?(reaction.reaction_value) &&
          reaction.reaction_users.find { |ru| ru.user_id == scope.user.id }.present?
      end

    like_post_action.present? && !has_matching_reaction_user
  end

  add_to_serializer(:topic_view, :valid_reactions) { DiscourseReactions::Reaction.valid_reactions }

  add_model_callback(User, :before_destroy) do
    DiscourseReactions::ReactionUser.where(user_id: self.id).delete_all
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
        html_title: PrettyText.unescape_emoji(CGI.escapeHTML(":#{main_id}:")),
      },
    ]

    reactions = SiteSetting.discourse_reactions_enabled_reactions.split("|") - [main_id]

    reactions.each do |reaction|
      report.labels << {
        type: :number,
        property: "#{reaction}_count",
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
