# frozen_string_literal: true

module DiscourseMcp
  module ToolHelpers
    module_function

    def text_and_structured(value)
      {
        content: [{ type: "text", text: JSON.generate(value) }],
        structuredContent: value,
        isError: false,
      }
    end

    def post_json(post)
      {
        id: post.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        username: post.username,
        raw: post.raw,
        created_at: post.created_at.iso8601,
        updated_at: post.updated_at.iso8601,
        url: post.full_url,
      }
    end

    def topic_json(topic)
      {
        id: topic.id,
        title: topic.title,
        slug: topic.slug,
        category_id: topic.category_id,
        tags: topic.tags.map(&:name),
        posts_count: topic.posts_count,
        created_at: topic.created_at.iso8601,
        last_posted_at: topic.last_posted_at&.iso8601,
        closed: topic.closed,
        archived: topic.archived,
        url: topic.url,
      }
    end
  end

  module Tools
    class CurrentUser
      def self.call(arguments:, principal:)
        user = principal.user or raise Discourse::InvalidAccess
        ToolHelpers.text_and_structured(
          id: user.id,
          username: user.username,
          name: user.name,
          trust_level: user.trust_level,
          admin: user.admin,
          moderator: user.moderator,
          scopes: principal.scopes.to_a.sort,
          resource: DiscourseMcp.resource_url,
        )
      end
    end

    class Search
      def self.call(arguments:, principal:)
        query = arguments.fetch("query").to_s
        limit = arguments.fetch("limit", 20).to_i.clamp(1, 50)
        results = ::Search.execute(query, guardian: principal.guardian)
        posts = results.posts.first(limit).map { |post| ToolHelpers.post_json(post) }
        ToolHelpers.text_and_structured(query: query, posts: posts)
      end
    end

    class GetTopic
      def self.call(arguments:, principal:)
        topic = Topic.find_by(id: arguments.fetch("topic_id").to_i)
        if topic.blank? || !principal.guardian.can_see?(topic)
          raise DiscourseMcp::ToolError, "Topic not found"
        end

        limit = arguments.fetch("post_limit", 50).to_i.clamp(1, 100)
        posts =
          Post
            .secured(principal.guardian)
            .where(topic_id: topic.id)
            .order(:post_number)
            .limit(limit)
        ToolHelpers.text_and_structured(
          topic: ToolHelpers.topic_json(topic),
          posts: posts.map { |post| ToolHelpers.post_json(post) },
        )
      end
    end

    class GetPost
      def self.call(arguments:, principal:)
        post = Post.secured(principal.guardian).find_by(id: arguments.fetch("post_id").to_i)
        if post.blank? || !principal.guardian.can_see?(post)
          raise DiscourseMcp::ToolError, "Post not found"
        end

        ToolHelpers.text_and_structured(post: ToolHelpers.post_json(post))
      end
    end

    class ListTopics
      def self.call(arguments:, principal:)
        limit = arguments.fetch("limit", 30).to_i.clamp(1, 50)
        topics = TopicQuery.new(principal.user).list_latest.topics.first(limit)
        ActiveRecord::Associations::Preloader.new(records: topics, associations: :tags).call
        ToolHelpers.text_and_structured(
          topics: topics.map { |topic| ToolHelpers.topic_json(topic) },
        )
      end
    end

    class ListCategories
      def self.call(arguments:, principal:)
        categories = Category.secured(principal.guardian).order(:position, :id).limit(500)
        ToolHelpers.text_and_structured(
          categories:
            categories.map do |category|
              {
                id: category.id,
                name: category.name,
                slug: category.slug,
                parent_category_id: category.parent_category_id,
                topic_count: category.topic_count,
              }
            end,
        )
      end
    end

    class ListTags
      def self.call(arguments:, principal:)
        column = Tag.topic_count_column(principal.guardian)
        tags = Tag.order(column => :desc).limit(arguments.fetch("limit", 100).to_i.clamp(1, 200))
        visible = DiscourseTagging.filter_visible(tags, principal.guardian)
        ToolHelpers.text_and_structured(
          tags:
            visible.map do |tag|
              { id: tag.id, name: tag.name, topic_count: tag.public_send(column) }
            end,
        )
      end
    end

    class GetUser
      def self.call(arguments:, principal:)
        user = User.find_by_username(arguments.fetch("username"))
        if user.blank? || !principal.guardian.can_see_profile?(user)
          raise DiscourseMcp::ToolError, "User not found"
        end

        ToolHelpers.text_and_structured(
          user: {
            id: user.id,
            username: user.username,
            name: user.name,
            trust_level: user.trust_level,
            created_at: user.created_at.iso8601,
          },
        )
      end
    end

    class ListBookmarks
      def self.call(arguments:, principal:)
        bookmarks =
          Bookmark
            .where(user_id: principal.user_id)
            .includes(:bookmarkable)
            .order(updated_at: :desc)
            .limit(arguments.fetch("limit", 50).to_i.clamp(1, 100))
        values =
          bookmarks.filter_map do |bookmark|
            bookmarkable = bookmark.bookmarkable
            next if bookmarkable.blank? || !principal.guardian.can_see?(bookmarkable)
            {
              id: bookmark.id,
              name: bookmark.name,
              reminder_at: bookmark.reminder_at&.iso8601,
              bookmarkable_type: bookmark.bookmarkable_type,
              bookmarkable_id: bookmark.bookmarkable_id,
            }
          end
        ToolHelpers.text_and_structured(bookmarks: values)
      end
    end

    class ListNotifications
      def self.call(arguments:, principal:)
        limit = arguments.fetch("limit", 50).to_i.clamp(1, 100)
        notifications =
          Notification
            .where(user_id: principal.user_id)
            .visible
            .includes(:topic)
            .order(id: :desc)
            .limit(limit)
        notifications =
          Notification.filter_inaccessible_topic_notifications(principal.guardian, notifications)
        notifications = Notification.filter_disabled_badge_notifications(notifications)
        notifications = Notification.populate_acting_user(notifications)
        serialized =
          notifications.map do |notification|
            NotificationSerializer.new(notification, scope: principal.guardian, root: false).as_json
          end
        ToolHelpers.text_and_structured(notifications: serialized)
      end
    end

    class CreateTopic
      def self.call(arguments:, principal:)
        post =
          PostCreator.create!(
            principal.user,
            title: arguments.fetch("title"),
            raw: arguments.fetch("raw"),
            category: arguments["category_id"],
            tags: Array(arguments["tags"]),
            skip_validations: false,
          )
        ToolHelpers.text_and_structured(
          post: ToolHelpers.post_json(post),
          topic: ToolHelpers.topic_json(post.topic),
        )
      end
    end

    class ReplyTopic
      def self.call(arguments:, principal:)
        post =
          PostCreator.create!(
            principal.user,
            topic_id: arguments.fetch("topic_id"),
            raw: arguments.fetch("raw"),
            reply_to_post_number: arguments["reply_to_post_number"],
          )
        ToolHelpers.text_and_structured(post: ToolHelpers.post_json(post))
      end
    end

    class EditPost
      def self.call(arguments:, principal:)
        post = Post.find_by(id: arguments.fetch("post_id").to_i)
        if post.blank? || !principal.guardian.can_edit_post?(post)
          raise DiscourseMcp::ToolError, "Post not found"
        end

        fields = { raw: arguments.fetch("raw") }
        fields[:edit_reason] = arguments["edit_reason"] if arguments["edit_reason"].present?
        PostRevisor.new(post, post.topic).revise!(principal.user, fields)
        ToolHelpers.text_and_structured(post: ToolHelpers.post_json(post.reload))
      end
    end

    class SetPostDeleted
      def self.call(arguments:, principal:)
        post = Post.find_by(id: arguments.fetch("post_id").to_i, user_id: principal.user_id)
        raise DiscourseMcp::ToolError, "Post not found" if post.blank?

        if arguments.fetch("deleted")
          raise Discourse::InvalidAccess if !principal.guardian.can_delete_post?(post)
          PostDestroyer.new(principal.user, post).destroy
        else
          raise Discourse::InvalidAccess if !principal.guardian.can_recover_post?(post)
          PostDestroyer.new(principal.user, post).recover
        end
        ToolHelpers.text_and_structured(post_id: post.id, deleted: arguments.fetch("deleted"))
      end
    end

    class SetUserStatus
      def self.call(arguments:, principal:)
        user = principal.user or raise Discourse::InvalidAccess
        if arguments.fetch("clear", false)
          user.clear_status!
        else
          user.set_status!(
            arguments.fetch("description"),
            arguments.fetch("emoji"),
            arguments["ends_at"],
          )
        end
        ToolHelpers.text_and_structured(success: true)
      end
    end
  end
end
