# frozen_string_literal: true

module DiscourseReactions
  class ReactionLikeSynchronizer
    BATCH_SIZE = 2_000

    def self.sync!
      new.sync!
    end

    def initialize
      @excluded_from_like = DiscourseReactions::Reaction.reactions_excluded_from_like
    end

    def sync!
      return if !SiteSetting.discourse_reactions_like_sync_enabled

      inserted = recovered = trashed = 0
      min_id, max_id = DiscourseReactions::ReactionUser.pick("MIN(id)", "MAX(id)")

      (min_id.to_i..max_id.to_i).step(BATCH_SIZE) do |batch_min_id|
        @reaction_user_ids = batch_min_id..(batch_min_id + BATCH_SIZE - 1)
        batch_inserted, batch_recovered, batch_trashed = sync_batch
        inserted += batch_inserted
        recovered += batch_recovered
        trashed += batch_trashed
      end

      Rails.logger.info(
        "[ReactionLikeSynchronizer] Inserted #{inserted}, recovered #{recovered} and trashed #{trashed} post action likes.",
      )
    end

    private

    def sync_batch
      ActiveRecord::Base.transaction do
        inserted_post_action_ids = create_missing_post_actions
        recovered_post_action_ids = recover_trashed_post_actions
        created_or_recovered_post_action_ids = inserted_post_action_ids + recovered_post_action_ids
        create_missing_user_actions(created_or_recovered_post_action_ids)

        trashed_post_action_ids = trash_excluded_post_actions
        delete_excluded_user_actions(trashed_post_action_ids)

        recalculate_counters(created_or_recovered_post_action_ids + trashed_post_action_ids)

        [
          inserted_post_action_ids.length,
          recovered_post_action_ids.length,
          trashed_post_action_ids.length,
        ]
      end
    end

    def recalculate_counters(post_action_ids)
      return if post_action_ids.empty?

      rows = DB.query(<<~SQL, post_action_ids:)
        SELECT post_actions.post_id, posts.topic_id, post_actions.user_id AS liker_id, posts.user_id AS author_id
        FROM post_actions
        INNER JOIN posts ON posts.id = post_actions.post_id
        WHERE post_actions.id IN (:post_action_ids)
      SQL
      post_ids = rows.map(&:post_id).uniq
      liker_ids = rows.map(&:liker_id).uniq

      Post.recalculate_like_counts!(post_ids)
      Topic.recalculate_like_counts!(rows.map(&:topic_id).uniq)
      UserStat.recalculate_likes!((liker_ids + rows.map(&:author_id)).compact.uniq)
      GivenDailyLike.recalculate!(liker_ids)
      TopicUser.update_post_action_cache(post_id: post_ids)
    end

    def create_missing_post_actions
      DB.query_single(<<~SQL, sql_params)
        WITH eligible AS (#{eligible_reaction_users_sql})
        INSERT INTO post_actions (post_id, user_id, post_action_type_id, created_at, updated_at)
        SELECT eligible.post_id, eligible.user_id, :pa_like, eligible.created_at, eligible.updated_at
        FROM eligible
        LEFT JOIN post_actions
          ON post_actions.user_id = eligible.user_id
          AND post_actions.post_id = eligible.post_id
          AND post_actions.post_action_type_id = :pa_like
        WHERE post_actions.id IS NULL
        ON CONFLICT DO NOTHING
        RETURNING post_actions.id
      SQL
    end

    def recover_trashed_post_actions
      DB.query_single(<<~SQL, sql_params)
        WITH eligible AS (#{eligible_reaction_users_sql}),
        recoverable AS (
          SELECT MAX(post_actions.id) AS id
          FROM post_actions
          INNER JOIN eligible
            ON eligible.user_id = post_actions.user_id
            AND eligible.post_id = post_actions.post_id
          WHERE post_actions.post_action_type_id = :pa_like
          GROUP BY post_actions.user_id, post_actions.post_id
          HAVING BOOL_AND(post_actions.deleted_at IS NOT NULL)
        )
        UPDATE post_actions
        SET deleted_at = NULL, deleted_by_id = NULL, updated_at = NOW()
        FROM recoverable
        WHERE post_actions.id = recoverable.id
        RETURNING post_actions.id
      SQL
    end

    # Create the corresponding UserAction records for the PostAction records. In
    # the ReactionManager, this is done via PostActionCreator.
    #
    # The only difference between LIKE and WAS LIKED is the user;
    #   * LIKE is the post action user because they are the one who liked the post
    #   * WAS LIKED is done by the post user, because they are the like-ee
    def create_missing_user_actions(post_action_ids)
      return if post_action_ids.empty?

      DB.exec(<<~SQL, **sql_params, post_action_ids:)
        INSERT INTO user_actions (
          action_type, user_id, acting_user_id, target_post_id, target_topic_id, created_at, updated_at
        )
        SELECT types.action_type,
               CASE types.action_type WHEN :ua_like THEN post_actions.user_id ELSE posts.user_id END,
               post_actions.user_id,
               post_actions.post_id,
               posts.topic_id,
               post_actions.created_at,
               post_actions.created_at
        FROM post_actions
        INNER JOIN posts ON posts.id = post_actions.post_id
        CROSS JOIN (VALUES (:ua_like), (:ua_was_liked)) AS types(action_type)
        WHERE post_actions.id IN (:post_action_ids) AND posts.user_id IS NOT NULL
        ON CONFLICT DO NOTHING
      SQL
    end

    def delete_excluded_user_actions(trashed_post_action_ids)
      return if trashed_post_action_ids.empty?

      DB.exec(<<~SQL, **sql_params, trashed_post_action_ids:)
        DELETE FROM user_actions
        USING post_actions
        WHERE post_actions.id IN (:trashed_post_action_ids)
          AND user_actions.target_post_id = post_actions.post_id
          AND user_actions.acting_user_id = post_actions.user_id
          AND user_actions.action_type IN (:ua_like, :ua_was_liked)
      SQL
    end

    def trash_excluded_post_actions
      return [] if @excluded_from_like.empty?

      DB.query_single(<<~SQL, sql_params)
        UPDATE post_actions
        SET deleted_at = NOW()
        FROM discourse_reactions_reaction_users ru
        INNER JOIN discourse_reactions_reactions ON discourse_reactions_reactions.id = ru.reaction_id
        WHERE post_actions.deleted_at IS NULL
          AND post_actions.user_id = ru.user_id
          AND post_actions.post_id = ru.post_id
          AND post_actions.post_action_type_id = :pa_like
          AND discourse_reactions_reactions.reaction_value IN (:excluded_from_like)
          AND ru.id BETWEEN :min_reaction_user_id AND :max_reaction_user_id
        RETURNING post_actions.id
      SQL
    end

    def eligible_reaction_users_sql
      <<~SQL
        SELECT ru.user_id, ru.post_id, ru.created_at, ru.updated_at
        FROM discourse_reactions_reaction_users ru
        INNER JOIN discourse_reactions_reactions ON discourse_reactions_reactions.id = ru.reaction_id
        INNER JOIN posts ON posts.id = ru.post_id
        WHERE ru.id BETWEEN :min_reaction_user_id AND :max_reaction_user_id
          AND posts.deleted_at IS NULL
          AND posts.user_id <> ru.user_id
          #{"AND discourse_reactions_reactions.reaction_value NOT IN (:excluded_from_like)" if @excluded_from_like.any?}
      SQL
    end

    def sql_params
      {
        pa_like: PostActionType::LIKE_POST_ACTION_ID,
        ua_like: UserAction::LIKE,
        ua_was_liked: UserAction::WAS_LIKED,
        excluded_from_like: @excluded_from_like,
        min_reaction_user_id: @reaction_user_ids.first,
        max_reaction_user_id: @reaction_user_ids.last,
      }
    end
  end
end
