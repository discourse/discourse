# frozen_string_literal: true

class Blog::Article::List
  include Service::Base

  MAX_QUERY_LENGTH = 100
  SEARCH_SQL =
    "blog_revisions.data->>'title' ILIKE :pattern OR blog_revisions.data->>'excerpt' ILIKE :pattern"

  params do
    attribute :page, :integer
    attribute :query, :string
    attribute :tag_slug, :string
    attribute :author_username, :string
    attribute :archive, :boolean, default: false

    before_validation do
      self.page = [page.to_i, 1].max
      self.query = query.to_s.strip.first(MAX_QUERY_LENGTH)
    end

    def offset(per_page) = (page - 1) * per_page

    def search_pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"

    def featured_first? = !archive && query.blank? && tag_slug.blank? && author_username.blank?
  end

  model :tag, optional: true
  policy :requested_tag_is_visible
  model :author, optional: true
  model :publications, optional: true
  # An empty author page would reveal which usernames exist.
  policy :requested_author_has_articles
  model :listing, :paginate_publications

  private

  def fetch_tag(params:)
    return if params.tag_slug.blank?
    Tag.visible(Guardian.new).find_by(slug: params.tag_slug)
  end

  def requested_tag_is_visible(params:, tag:)
    params.tag_slug.blank? || tag.present?
  end

  def fetch_author(params:)
    return if params.author_username.blank?
    User.human_users.find_by(username_lower: User.normalize_username(params.author_username))
  end

  def fetch_publications(params:, tag:, author:)
    publications = Blog::Publication.publicly_visible
    if params.query.present?
      publications = publications.where(SEARCH_SQL, pattern: params.search_pattern)
    end
    publications = publications.where(discussion_topic_id: tag.topic_tags.select(:topic_id)) if tag
    if author
      publications =
        publications.where(
          "topics.user_id = :id OR :id = ANY(blog_publications.co_author_ids)",
          id: author.id,
        )
    end
    publications = publications.order(featured: :desc) if params.featured_first?
    publications.newest
  end

  def requested_author_has_articles(params:, author:, publications:)
    params.author_username.blank? || (author.present? && publications.exists?)
  end

  def paginate_publications(params:, publications:)
    per_page = SiteSetting.blog_posts_per_page
    window =
      publications
        .offset(params.offset(per_page))
        .limit(per_page + 1)
        .includes(:published_revision, discussion_topic: %i[first_post user image_upload tags])
        .to_a
    { publications: window.first(per_page), has_more: window.size > per_page }
  end
end
