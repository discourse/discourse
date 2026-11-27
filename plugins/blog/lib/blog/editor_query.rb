# frozen_string_literal: true

module ::Blog
  class EditorQuery
    FILTERS = %w[all drafts published unpublished pages].freeze
    MAX_QUERY_LENGTH = 100

    def self.call(guardian, filter: "all", query: "", blog: nil)
      raise Discourse::InvalidParameters.new(:filter) if FILTERS.exclude?(filter)
      if !query.is_a?(String) || query.length > MAX_QUERY_LENGTH
        raise Discourse::InvalidParameters.new(:q)
      end

      topics =
        Topic
          .secured(guardian)
          .listable_topics
          .where(category_id: [*Instance.category_ids, SiteSetting.blog_drafts_category.to_i])
          .where.not(id: Category.where.not(topic_id: nil).select(:topic_id))

      topics =
        topics.where.not(
          id:
            Publication
              .where.not(draft_topic_id: nil)
              .where("draft_topic_id <> topic_id")
              .select(:draft_topic_id),
        )
      topics =
        topics.where.not(
          id:
            Publication
              .where.not(discussion_topic_id: nil)
              .where("discussion_topic_id <> topic_id")
              .select(:discussion_topic_id),
        )
      visible_sources = Topic.secured(guardian).select(:id)
      topics =
        topics.where.not(
          id:
            Publication
              .where.not(draft_topic_id: nil)
              .where.not(draft_topic_id: visible_sources)
              .select(:topic_id),
        )
      topics = topics.where(user_id: guardian.user.id) unless guardian.is_blog_editor?
      topics = in_blog(topics, blog) if blog

      live_ids = Publication.publicly_visible.select("blog_publications.topic_id")
      topics =
        case filter
        when "drafts"
          topics
            .where(category_id: SiteSetting.blog_drafts_category.to_i)
            .where.not(id: Publication.where(published: true).select(:topic_id))
        when "published"
          topics.where(id: live_ids)
        when "unpublished"
          topics.where(category_id: Instance.category_ids).where.not(id: live_ids)
        when "pages"
          # A staged page setting wins over the live one, as in the article settings.
          topics.where(
            id:
              Publication.where("COALESCE((draft_metadata->>'page')::boolean, page)").select(
                :topic_id,
              ),
          )
        else
          topics
        end

      if query.strip.present?
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query.strip)}%"
        path_matches =
          Publication
            .where("path ILIKE ? OR draft_metadata->>'path' ILIKE ?", pattern, pattern)
            .or(
              Publication.where(
                draft_topic_id:
                  Topic.where("title ILIKE ? OR slug ILIKE ?", pattern, pattern).select(:id),
              ),
            )
            .select(:topic_id)
        topics =
          topics.where("topics.title ILIKE ? OR topics.slug ILIKE ?", pattern, pattern).or(
            topics.where(id: path_matches),
          )
      end

      topics.order(updated_at: :desc, id: :desc)
    end

    # A topic without a publication yet belongs where it would be published, as
    # in Publication#assign_blog: its public category's blog, otherwise the default.
    def self.in_blog(topics, blog)
      unassigned_categories = [blog.category_id]
      unassigned_categories << SiteSetting.blog_drafts_category.to_i if blog.is_default?
      topics.where(id: Publication.where(blog_id: blog.id).select(:topic_id)).or(
        topics
          .where.not(id: Publication.select(:topic_id))
          .where(category_id: unassigned_categories.compact),
      )
    end
    private_class_method :in_blog
  end
end
