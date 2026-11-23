# frozen_string_literal: true

module ::Blog
  # One blog on the site. Named Instance because a Blog::Blog model would shadow
  # the namespace for every Blog:: reference inside it.
  class Instance < ActiveRecord::Base
    self.table_name = "blog_instances"

    SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    URL_FORMAT = %r{\Ahttps://[a-z0-9.-]+(?::[0-9]+)?\z}
    DEFAULT_SLUG = "blog"
    DEFAULT_NAME = "The blog"

    belongs_to :category, optional: true

    normalizes :url, with: ->(url) { url.presence }

    validates :name, presence: true
    validates :slug,
              presence: true,
              uniqueness: {
                message: ->(*) { I18n.t("blog.errors.blog_slug_in_use") },
              },
              format: {
                with: SLUG_FORMAT,
              }
    validates :url, uniqueness: true, format: { with: URL_FORMAT }, allow_nil: true
    validates :category_id, uniqueness: true, allow_nil: true
    validates :posts_per_page, numericality: { only_integer: true, in: 1..30 }
    validates :is_default, uniqueness: true, if: :is_default?
    validate :path_format_valid
    validate :slug_routable, unless: :is_default?
    validate :url_not_forum_host
    validate :custom_domain_allowed, if: -> { url.present? && will_save_change_to_url? }
    validate :default_published, if: :is_default?
    validate :category_not_drafts, if: :category_id?
    validate :slug_kept_once_published, if: -> { persisted? && will_save_change_to_slug? }
    validate :category_kept_once_published,
             if: -> { persisted? && will_save_change_to_category_id? }

    after_commit do
      self.class.clear_cache
      # The site data sent to visitors lists the published blogs.
      Site.clear_anon_cache!
    end

    scope :ordered, -> { order(:position, :id) }

    # Blogs are read on every request, from hostname checks to topic validation, so
    # they come from memory. Cached rows are shared, so they are read-only.
    def self.cached
      cache.defer_get_set("all") { ordered.to_a.each(&:readonly!).freeze }
    end

    def self.cache
      @cache ||= DistributedCache.new("blog_instances")
    end

    def self.clear_cache
      cache.clear(after_commit: false)
    end

    # The fixture creates the row on every site, so the fallback only covers a
    # database that has not been seeded yet.
    def self.default_blog
      cached.find(&:is_default?) || new(is_default: true, slug: DEFAULT_SLUG)
    end

    # Every site has a default blog, so the fixture adds it on each deploy that
    # finds none.
    def self.ensure_default!
      find_or_create_by!(is_default: true) do |blog|
        blog.assign_attributes(slug: DEFAULT_SLUG, name: DEFAULT_NAME)
      end
    end

    # The one place that decides whether another blog may be added.
    def self.addable?
      count < SiteSetting.blog_max_instances
    end

    def self.find_cached(id)
      cached.find { |blog| blog.id == id }
    end

    def self.category_ids
      cached.filter_map(&:category_id)
    end

    # Articles keep their addresses, so a blog's slug stays once they are public.
    def slug_locked?
      Publication.where(blog_id: id).where.not(published_revision_id: nil).exists?
    end

    # An article is public only while its discussion sits in a blog's category, so
    # moving the blog to another category would take its articles offline. A
    # category that no longer exists can still be replaced.
    def category_locked?
      slug_locked? && Category.exists?(id: category_id_in_database)
    end

    private

    def path_format_valid
      format = PathFormat.for_blog(self)
      return errors.add(:path_format, I18n.t("blog.errors.path_format")) if !format.valid?
      return if !is_default?
      slug =
        self.class.where(is_default: false).pluck(:slug).find { format.fixed_first_segment?(it) }
      errors.add(:path_format, I18n.t("blog.errors.path_format_blog_slug", slug:)) if slug
    end

    # Other blogs live at /blog/<slug>, next to the default blog's own routes
    # and articles, so a slug must not be either.
    def slug_routable
      return if slug.blank?
      if (Publication::RESERVED_SEGMENTS + Routes::RESERVED_EXACT_SEGMENTS).include?(slug)
        return errors.add(:slug, I18n.t("blog.errors.blog_slug_reserved"))
      end
      default_blog = self.class.find_by(is_default: true)
      return if default_blog.nil?
      if PathFormat.for_blog(default_blog).fixed_first_segment?(slug)
        return errors.add(:slug, I18n.t("blog.errors.blog_slug_reserved"))
      end
      first_segments =
        Path.where(blog_id: default_blog.id).where("LOWER(SPLIT_PART(path, '/', 2)) = ?", slug)
      errors.add(:slug, I18n.t("blog.errors.blog_slug_taken")) if first_segments.exists?
    end

    def default_published
      errors.add(:published, I18n.t("blog.errors.default_blog_published")) if !published?
    end

    # Drafts must stay private, so the drafts category cannot hold discussions.
    def category_not_drafts
      return if category_id != SiteSetting.blog_drafts_category.to_i
      errors.add(:category_id, I18n.t("blog.errors.blog_category_is_drafts"))
    end

    def slug_kept_once_published
      errors.add(:slug, I18n.t("blog.errors.blog_slug_locked")) if slug_locked?
    end

    def category_kept_once_published
      return if !category_locked?
      errors.add(:category_id, I18n.t("blog.errors.blog_category_locked"))
    end

    # A blog that already has its own domain keeps it when the site loses the option.
    def custom_domain_allowed
      return if SiteSetting.blog_custom_domains_enabled
      errors.add(:url, I18n.t("blog.errors.blog_url_unavailable"))
    end

    def url_not_forum_host
      return if url.blank? || URI(url).host != Discourse.current_hostname
      errors.add(:url, I18n.t("blog.errors.blog_url_forum_host"))
    rescue URI::InvalidURIError
      nil
    end
  end
end

# == Schema Information
#
# Table name: blog_instances
#
#  id             :bigint           not null, primary key
#  about          :text             default(""), not null
#  active_theme   :jsonb
#  description    :text             default(""), not null
#  is_default     :boolean          default(FALSE), not null
#  name           :string           not null
#  path_format    :string           default("/{slug}"), not null
#  position       :integer          default(0), not null
#  posts_per_page :integer          default(10), not null
#  published      :boolean          default(TRUE), not null
#  slug           :string           not null
#  url            :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :integer
#
# Indexes
#
#  index_blog_instances_on_category_id  (category_id) UNIQUE
#  index_blog_instances_on_is_default   (is_default) UNIQUE WHERE is_default
#  index_blog_instances_on_slug         (slug) UNIQUE
#  index_blog_instances_on_url          (url) UNIQUE
#
