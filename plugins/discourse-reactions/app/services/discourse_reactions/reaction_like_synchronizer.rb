# frozen_string_literal: true

module DiscourseReactions
  class ReactionLikeSynchronizer
    def self.sync!
      self.new.sync!
    end

    def initialize
      @excluded_from_like = DiscourseReactions::Reaction.reactions_excluded_from_like
    end

    def sync!
      return if !SiteSetting.discourse_reactions_like_sync_enabled

      pre_run_report = DiscourseReactions::MigrationReport.run(print_report: false)
      Rails.logger.info(
        "[ReactionLikeSynchronizer] Starting sync.... Pre-run report:\n\n#{DiscourseReactions::MigrationReport.humanized_report_data(pre_run_report)}",
      )

      # We want this to be all-or-nothing because the scope of each update/insert/delete
      # batch is so dependent on the `all_affected_post_action_ids` or previously affected
      # IDs. If we don't do this in a transaction, we could end up with a partial update
      # on error and have no easy way of correcting data.
      ActiveRecord::Base.transaction do
        inserted_post_action_ids = create_missing_post_actions
        recovered_post_action_ids = recover_trashed_post_actions

        created_or_recovered_post_action_ids =
          (recovered_post_action_ids + inserted_post_action_ids).uniq

        Rails.logger.info(
          "[ReactionLikeSynchronizer] Inserted #{inserted_post_action_ids.length} post action likes, recovered #{recovered_post_action_ids.length} trashed post action likes. (#{created_or_recovered_post_action_ids.length} total)",
        )

        create_missing_user_actions(created_or_recovered_post_action_ids)

        trashed_post_action_ids = trash_excluded_post_actions
        Rails.logger.info(
          "[ReactionLikeSynchronizer] Trashed #{trashed_post_action_ids.length} post action likes.",
        )
        delete_excluded_user_actions(trashed_post_action_ids)

        all_affected_post_action_ids =
          (created_or_recovered_post_action_ids + trashed_post_action_ids).uniq

        update_post_like_counts(all_affected_post_action_ids)
        update_topic_like_counts(all_affected_post_action_ids)
        update_user_stats(all_affected_post_action_ids)
        upsert_given_daily_likes(all_affected_post_action_ids)

        TopicUser.update_post_action_cache(
          post_id:
            PostAction.with_deleted.where(id: all_affected_post_action_ids).pluck(:post_id).uniq,
        )
      end

      post_run_report =
        DiscourseReactions::MigrationReport.run(
          print_report: false,
          previous_report_data: pre_run_report,
        )

      Rails.logger.info(
        "[ReactionLikeSynchronizer] Sync completed! Post-run report:\n\n#{DiscourseReactions::MigrationReport.humanized_report_data(post_run_report, pre_run_report)}",
      )

      { pre_run_report:, post_run_report: }
    end

    # Find all ReactionUser records that do not have a corresponding
    # PostAction like record, for any reactions that are not in
    # excluded_from_like, and create a PostAction record for each.
    def create_missing_post_actions
      sql_query = <<~SQL
        INSERT INTO post_actions(
          post_id, user_id, post_action_type_id, created_at, updated_at
        )
        SELECT ru.post_id, ru.user_id, :pa_like, ru.created_at, ru.updated_at
        FROM discourse_reactions_reaction_users ru
        INNER JOIN discourse_reactions_reactions
          ON discourse_reactions_reactions.id = ru.reaction_id
        LEFT JOIN post_actions
          ON post_actions.user_id = ru.user_id
          AND post_actions.post_id = ru.post_id
        WHERE post_actions.id IS NULL
        #{@excluded_from_like.any? ? " AND discourse_reactions_reactions.reaction_value NOT IN (:excluded_from_like)" : ""}
        RETURNING post_actions.id
      SQL

      DB.query_single(
        sql_query,
        pa_like: PostActionType::LIKE_POST_ACTION_ID,
        excluded_from_like: @excluded_from_like,
      )
    end

    # Find all trashed PostAction records matching ReactionUser records,
    # which are not in excluded_from_like, and untrash them.
    def recover_trashed_post_actions
      sql_query = <<~SQL
        UPDATE post_actions
        SET deleted_at = NULL, deleted_by_id = NULL, updated_at = NOW()
        FROM discourse_reactions_reaction_users ru
        INNER JOIN discourse_reactions_reactions
          ON discourse_reactions_reactions.id = ru.reaction_id
        WHERE post_actions.deleted_at IS NOT NULL AND post_actions.user_id = ru.user_id
          AND post_actions.post_id = ru.post_id AND post_actions.post_action_type_id = :pa_like
        #{@excluded_from_like.any? ? " AND discourse_reactions_reactions.reaction_value NOT IN (:excluded_from_like)" : ""}
      SQL

      DB.query_single(
        sql_query,
        pa_like: PostActionType::LIKE_POST_ACTION_ID,
        excluded_from_like: @excluded_from_like,
      )
    end

    # Create the corresponding UserAction records for the PostAction records. In
    # the ReactionManager, this is done via PostActionCreator.
    #
    # The only difference between LIKE and WAS LIKED is the user;
    #   * LIKE is the post action user because they are the one who liked the post
    #   * WAS LIKED is done by the post user, because they are the like-ee
    #
    # No need to do any UserAction inserts if there wasn't any PostAction changes.
    def create_missing_user_actions(post_action_ids)
      return if post_action_ids.none?

      sql_query = <<~SQL
        INSERT INTO user_actions (
          action_type, user_id, acting_user_id, target_post_id, target_topic_id, created_at, updated_at
        )
        SELECT :ua_like,
               post_actions.user_id,
               post_actions.user_id,
               post_actions.post_id,
               posts.topic_id,
               post_actions.created_at,
               post_actions.created_at
        FROM post_actions
        INNER JOIN posts ON posts.id = post_actions.post_id
        WHERE post_actions.id IN (:post_action_ids) AND posts.user_id IS NOT NULL
        ON CONFLICT DO NOTHING
      SQL
      inserted_user_action_count =
        DB.exec(sql_query, ua_like: UserAction::LIKE, post_action_ids: post_action_ids)
      Rails.logger.info(
        "[ReactionsLikeSynchronizer] Inserted #{inserted_user_action_count} like UserActions",
      )

      sql_query = <<~SQL
        INSERT INTO user_actions (
          action_type, user_id, acting_user_id, target_post_id, target_topic_id, created_at, updated_at
        )
        SELECT :ua_was_liked,
               posts.user_id,
               post_actions.user_id,
               post_actions.post_id,
               posts.topic_id,
               post_actions.created_at,
               post_actions.created_at
        FROM post_actions
        INNER JOIN posts ON posts.id = post_actions.post_id
        WHERE post_actions.id IN (:post_action_ids) AND posts.user_id IS NOT NULL
        ON CONFLICT DO NOTHING
      SQL
      inserted_user_action_count =
        DB.exec(sql_query, ua_was_liked: UserAction::WAS_LIKED, post_action_ids: post_action_ids)
      Rails.logger.info(
        "[ReactionsLikeSynchronizer] Inserted #{inserted_user_action_count} was_liked UserActions",
      )
    end

    # Delete any UserAction records for LIKE or WAS_LIKED that match up with
    # PostAction records that got trashed.
    def delete_excluded_user_actions(trashed_post_action_ids)
      return if trashed_post_action_ids.empty?

      sql_query = <<~SQL
        DELETE FROM user_actions
        WHERE id IN (
          -- Select IDs for LIKED actions
          SELECT user_actions.id
          FROM user_actions
          INNER JOIN post_actions ON user_actions.target_post_id = post_actions.post_id
            AND user_actions.acting_user_id = post_actions.user_id
          WHERE post_actions.id IN (:trashed_post_action_ids)
          AND user_actions.action_type = :ua_like

          UNION

          -- Select IDs for WAS_LIKED actions
          SELECT user_actions.id
          FROM user_actions user_actions
          INNER JOIN post_actions ON user_actions.target_post_id = post_actions.post_id
          INNER JOIN posts ON posts.id = post_actions.post_id
          WHERE post_actions.id IN (:trashed_post_action_ids)
          AND user_actions.action_type = :ua_was_liked
          AND user_actions.user_id = posts.user_id
          AND user_actions.acting_user_id = post_actions.user_id
        )
      SQL
      DB.exec(
        sql_query,
        ua_like: UserAction::LIKE,
        ua_was_liked: UserAction::WAS_LIKED,
        trashed_post_action_ids: trashed_post_action_ids,
      )
    end

    # Find all PostAction records that have a ReactionUser record that
    # uses a reaction in the excluded_from_like list and trash them.
    def trash_excluded_post_actions
      return [] if @excluded_from_like.none?

      sql_query = <<~SQL
        UPDATE post_actions
        SET deleted_at = NOW()
        FROM discourse_reactions_reaction_users ru
        INNER JOIN discourse_reactions_reactions ON discourse_reactions_reactions.id = ru.reaction_id
        WHERE post_actions.user_id = ru.user_id
          AND post_actions.post_id = ru.post_id
          AND post_actions.post_action_type_id = :like
          AND discourse_reactions_reactions.reaction_value IN (:excluded_from_like)
        RETURNING post_actions.id
      SQL

      DB.query_single(
        sql_query,
        like: PostActionType::LIKE_POST_ACTION_ID,
        excluded_from_like: @excluded_from_like,
        ua_like: UserAction::LIKE,
        ua_was_liked: UserAction::WAS_LIKED,
      )
    end

    # Update the like_count counter cache on all Post records
    # affected by created/recovered/trashed post actions.
    def update_post_like_counts(all_affected_post_action_ids)
      post_ids = DB.query_single(<<~SQL, post_action_ids: all_affected_post_action_ids)
        SELECT DISTINCT post_id
        FROM post_actions
        WHERE ID IN (:post_action_ids)
      SQL

      sql_query = <<~SQL
        UPDATE posts
        SET like_count = (
          SELECT COUNT(*)
          FROM post_actions
          WHERE post_actions.post_id = posts.id
          AND post_action_type_id = 2
          AND post_actions.deleted_at IS NULL
        )
        WHERE posts.id IN (:post_ids)
      SQL
      DB.exec(sql_query, post_ids: post_ids)
    end

    # Update the like_count counter cache on all Topic records
    # affected by created/recovered/trashed post actions.
    def update_topic_like_counts(all_affected_post_action_ids)
      topic_ids = DB.query_single(<<~SQL, post_action_ids: all_affected_post_action_ids)
        SELECT DISTINCT topic_id
        FROM posts
        INNER JOIN post_actions ON post_actions.post_id = posts.id
        WHERE post_actions.id IN (:post_action_ids)
      SQL

      sql_query = <<~SQL
        UPDATE topics
        SET like_count = (
          SELECT SUM(like_count)
          FROM posts
          WHERE posts.topic_id = topics.id
        )
        WHERE topics.id IN (:topic_ids)
      SQL

      DB.exec(sql_query, topic_ids: topic_ids)
    end

    # Update the likes_given and likes_received counter caches on the
    # UserStat table based on posts matching up with created/restored/trashed
    # post actions.
    #
    # The UserAction records (which are created/deleted before this) are an
    # easier way to calculate this rather than going via PostAction again.
    def update_user_stats(all_affected_post_action_ids)
      return if all_affected_post_action_ids.empty?

      users_needing_likes_received_recalc = DB.query_single(<<~SQL, all_affected_post_action_ids)
        SELECT DISTINCT posts.user_id
        FROM posts
        INNER JOIN post_actions ON post_actions.post_id = posts.id
        WHERE post_actions.id IN (?)
      SQL

      if users_needing_likes_received_recalc.any?
        # NOTE: UserAction created as a result of a PostAction like
        # will have acting_user_id, target_post_id, and target_topic_id
        # filled but NOT target_user_id, see UserActionManager.post_action_rows
        sql_query = <<~SQL
          WITH likes_received_cte AS (
            SELECT posts.user_id AS user_id, COUNT(user_actions.id) AS new_likes_received
            FROM user_actions
            INNER JOIN posts ON user_actions.target_post_id = posts.id
            WHERE user_actions.action_type = :ua_was_liked
              AND posts.user_id IN (:affected_user_ids)
            GROUP BY posts.user_id
          )
          UPDATE user_stats
          SET likes_received = lrc.new_likes_received
          FROM likes_received_cte lrc
          WHERE user_stats.user_id = lrc.user_id
          RETURNING user_stats.user_id
        SQL

        changed_user_ids =
          DB.query_single(
            sql_query,
            affected_user_ids: users_needing_likes_received_recalc,
            ua_was_liked: UserAction::WAS_LIKED,
          )
        UserStat.where(user_id: users_needing_likes_received_recalc - changed_user_ids).update_all(
          likes_received: 0,
        )
      end

      users_needing_likes_given_recalc = DB.query_single(<<~SQL, all_affected_post_action_ids)
        SELECT DISTINCT user_id
        FROM post_actions
        WHERE post_actions.id IN (?)
      SQL

      if users_needing_likes_given_recalc.any?
        sql_query = <<~SQL
          WITH likes_given_cte AS (
            SELECT user_actions.acting_user_id AS user_id, COUNT(user_actions.id) AS new_likes_given
            FROM user_actions
            WHERE user_actions.action_type = :ua_like
              AND user_actions.acting_user_id IN (:affected_user_ids)
            GROUP BY user_actions.acting_user_id
          )
          UPDATE user_stats
          SET likes_given = lgc.new_likes_given
          FROM likes_given_cte lgc
          WHERE user_stats.user_id = lgc.user_id
          RETURNING user_stats.user_id
        SQL

        changed_user_ids =
          DB.query_single(
            sql_query,
            affected_user_ids: users_needing_likes_given_recalc,
            ua_like: UserAction::LIKE,
          )
        UserStat.where(user_id: users_needing_likes_given_recalc - changed_user_ids).update_all(
          likes_given: 0,
        )
      end
    end

    # Upsert any existing GivenDailyLike records for the users who created
    # or were affected by the created/restored/trashed post actions. There
    # is a count per day per user that needs to be recalculated.
    #
    # We delete any GivenDailyLike records that would equate to a count of 0
    # for that day and that user, which is based on UserAction records (which
    # are created or destroyed before this).
    def upsert_given_daily_likes(all_affected_post_action_ids)
      return if all_affected_post_action_ids.blank?

      sql_query = <<~SQL
        SELECT user_id
        FROM post_actions
        WHERE post_actions.id = ANY(ARRAY[:all_affected_post_action_ids])
        UNION
        SELECT posts.user_id
        FROM posts
        INNER JOIN post_actions ON post_actions.post_id = posts.id 
        WHERE post_actions.id = ANY(ARRAY[:all_affected_post_action_ids])
      SQL
      user_ids =
        DB.query_single(sql_query, all_affected_post_action_ids: all_affected_post_action_ids)

      return if user_ids.blank?

      sql_query = <<~SQL
        INSERT INTO given_daily_likes (user_id, given_date, likes_given)
        SELECT user_actions.acting_user_id, DATE(user_actions.created_at) AS given_date, COUNT(*) AS likes_given
        FROM user_actions
        WHERE user_actions.action_type = :ua_like
          AND user_actions.acting_user_id IN (:user_ids)
        GROUP BY user_actions.acting_user_id, DATE(user_actions.created_at)
        ON CONFLICT (user_id, given_date)
        DO UPDATE SET likes_given = EXCLUDED.likes_given
      SQL
      DB.exec(sql_query, ua_like: UserAction::LIKE, user_ids: user_ids)

      sql_query = <<~SQL
        DELETE FROM given_daily_likes gdl
        WHERE NOT EXISTS (
          SELECT 1
          FROM user_actions
          WHERE
              user_actions.acting_user_id = gdl.user_id
              AND user_actions.action_type = :ua_like
              AND DATE(user_actions.created_at) = gdl.given_date
        ) AND gdl.user_id IN (:user_ids)
      SQL
      DB.exec(sql_query, ua_like: UserAction::LIKE, user_ids: user_ids)
    end
  end
end
