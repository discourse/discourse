# frozen_string_literal: true

module NestedReplies
  class PostPreloader
    def initialize(topic_view:, topic:, current_user:, guardian:)
      @topic_view = topic_view
      @topic = topic
      @current_user = current_user
      @guardian = guardian
    end

    def prepare(posts)
      user_ids = posts.map(&:user_id).compact.uniq

      @topic_view.reset_post_collection(posts: PostsArray.new(posts))

      allowed_post_fields = TopicView.allowed_post_custom_fields(@current_user, @topic)
      @topic_view.post_custom_fields =
        if allowed_post_fields.present?
          Post.custom_fields_for_ids(posts.map(&:id).uniq, allowed_post_fields)
        else
          {}
        end

      allowed_user_fields = User.allowed_user_custom_fields(@guardian)
      @topic_view.user_custom_fields =
        if allowed_user_fields.present?
          User.custom_fields_for_ids(user_ids, allowed_user_fields)
        else
          {}
        end

      TopicView.preload(@topic_view)

      preload_plugin_associations(posts)
    end

    private

    # Thin Array subclass that intercepts the ActiveRecord-style methods
    # other plugins' on_preload hooks call on topic_view.posts.
    class PostsArray < Array
      def includes(*associations)
        ActiveRecord::Associations::Preloader.new(records: self, associations: associations).call
        self
      end

      def pluck(*columns)
        if columns.one?
          map(&columns.first)
        else
          map { |record| columns.map { |col| record.public_send(col) } }
        end
      end

      def where(conditions = nil, *rest)
        return self if conditions.nil?
        result =
          select do |record|
            if conditions.is_a?(Hash)
              conditions.all? { |k, v| record.public_send(k) == v }
            else
              true
            end
          end
        PostsArray.new(result)
      end

      def limit(_n)
        self
      end

      def order(*_args)
        self
      end

      def not(*_args)
        self
      end

      def reorder(*_args)
        self
      end
    end

    def preload_plugin_associations(posts)
      ActiveRecord::Associations::Preloader.new(records: posts, associations: [:post_actions]).call

      if defined?(DiscourseReactions) && SiteSetting.respond_to?(:discourse_reactions_enabled) &&
           SiteSetting.discourse_reactions_enabled
        ActiveRecord::Associations::Preloader.new(
          records: posts,
          associations: [{ reactions: { reaction_users: :user } }],
        ).call

        post_ids = posts.map(&:id).uniq
        if TopicViewSerializer.respond_to?(:posts_reaction_users_count)
          counts = TopicViewSerializer.posts_reaction_users_count(post_ids)
          action_users =
            DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
              post_ids,
            )
          posts.each do |post|
            post.reaction_users_count = counts[post.id].to_i
            post.post_actions_with_reaction_users = action_users[post.id] || {}
          end
        end

        NestedReplies.batch_precompute_reactions(posts, post_ids)
      end
    end
  end
end
