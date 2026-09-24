# frozen_string_literal: true

module DiscourseRewind
  module Action
    class Fbff < BaseReport
      MAX_SUMMARY_RESULTS = 50
      LIKE_SCORE = 1
      REPLY_SCORE = 10

      FakeData = {
        data: {
          fbff: {
            id: 2,
            username: "codingpal",
            name: "Coding Pal",
            avatar_template: "/letter_avatar_proxy/v4/letter/c/3be4f8/{size}.png",
          },
          yourself: {
            id: 1,
            username: "you",
            name: "You",
            avatar_template: "/letter_avatar_proxy/v4/letter/y/f05b48/{size}.png",
          },
        },
        identifier: "fbff",
      }

      def call
        return FakeData if should_use_fake_data?

        scores = Hash.new(0)
        [
          [like_query.where(acting_user_id: user.id), :user_id, LIKE_SCORE],
          [like_query.where(user_id: user.id), :acting_user_id, LIKE_SCORE],
          [post_query.where(posts: { user_id: user.id }), "replies.user_id", REPLY_SCORE],
          [post_query.where(replies: { user_id: user.id }), "posts.user_id", REPLY_SCORE],
        ].each do |query, friend_column, weight|
          query
            .where(friend_column => eligible_users)
            .group(friend_column)
            .order("COUNT(*) DESC")
            .limit(MAX_SUMMARY_RESULTS)
            .count
            .each { |user_id, count| scores[user_id] += count * weight }
        end

        fbff_id = scores.max_by(&:last)&.first
        return if !fbff_id

        {
          data: {
            fbff: BasicUserSerializer.new(User.find(fbff_id), root: false).as_json,
            yourself: BasicUserSerializer.new(user, root: false).as_json,
          },
          identifier: "fbff",
        }
      end

      def post_query
        self
          .class
          .publicly_visible_posts
          .joins(
            "INNER JOIN posts replies ON replies.topic_id = posts.topic_id AND replies.post_number = posts.reply_to_post_number",
          )
          .where(posts: { post_type: Post.types[:regular], created_at: date })
          .where(
            replies: {
              post_type: Post.types[:regular],
              hidden: false,
              created_at: date,
              deleted_at: nil,
            },
          )
          .where("replies.user_id <> posts.user_id")
      end

      def like_query
        UserAction
          .joins(:target_topic, :target_post)
          .merge(self.class.publicly_visible_topics)
          .where(action_type: UserAction::WAS_LIKED, created_at: date)
          .where(posts: { post_type: Post.types[:regular], hidden: false })
      end

      private

      def eligible_users
        @eligible_users ||=
          User
            .real
            .activated
            .not_suspended
            .where.not(id: user.muted_user_ids | user.ignored_user_ids)
            .select(:id)
      end
    end
  end
end
