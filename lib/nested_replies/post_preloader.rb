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
    end

    private

    # Array subclass that handles ActiveRecord-style methods called by plugins'
    # TopicView.on_preload hooks. The posts are already loaded with associations
    # by TreeLoader, so we avoid re-querying. Explicitly handles the methods
    # plugins actually use; unknown AR methods fall back to a real relation.
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
        if conditions.is_a?(Hash) && rest.empty?
          PostsArray.new(select { |record| conditions.all? { |k, v| record.public_send(k) == v } })
        else
          Post.where(id: map(&:id)).where(conditions, *rest)
        end
      end

      def limit(_n)
        self
      end

      def order(*_args)
        self
      end

      def not(conditions = {})
        if conditions.is_a?(Hash)
          PostsArray.new(reject { |record| conditions.all? { |k, v| record.public_send(k) == v } })
        else
          Post.where(id: map(&:id)).where.not(conditions)
        end
      end

      def reorder(*_args)
        self
      end

      def respond_to_missing?(name, include_private = false)
        Post.none.respond_to?(name, include_private) || super
      end

      def method_missing(name, *args, **kwargs, &block)
        relation = Post.none
        if relation.respond_to?(name)
          Post.where(id: map(&:id)).public_send(name, *args, **kwargs, &block)
        else
          super
        end
      end
    end
  end
end
