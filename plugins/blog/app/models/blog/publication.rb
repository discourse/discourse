# frozen_string_literal: true

module ::Blog
  class Publication < ActiveRecord::Base
    self.table_name = "blog_publications"
    MIDDLEWARE_SEGMENTS = %w[auth message-bus mini-profiler-resources].freeze
    RESERVED_SEGMENTS =
      (Routes::RESERVED_SEGMENTS + Configuration::ASSET_PREFIXES + MIDDLEWARE_SEGMENTS).freeze
    METADATA = %w[path excerpt featured published_at meta_description canonical_url].freeze
    MAX_PATH_LENGTH = 240
    # Encoded "+" and ",", and encoded UTF-8 bytes, so imported paths keep non-ASCII slugs.
    # Other encoded ASCII stays out: it could hide a separator, a dot segment or a control character.
    PATH_SEGMENT = /(?:[a-zA-Z0-9_+.,-]|%2[bBcC]|%[89a-fA-F]\h)+/
    PATH_PATTERN = %r{\A(?:/#{PATH_SEGMENT})+\z}
    # Invisible or unassigned characters would make a path display as something it isn't.
    HIDDEN_PATH_CHARACTERS = /[\p{Cc}\p{Cf}\p{Co}\p{Cn}\p{Z}]/

    belongs_to :topic
    belongs_to :draft_topic, class_name: "Topic", optional: true
    belongs_to :discussion_topic, class_name: "Topic", optional: true
    belongs_to :publisher, class_name: "User", optional: true
    belongs_to :scheduler, class_name: "User", optional: true
    belongs_to :published_revision, class_name: "Blog::Revision", optional: true
    belongs_to :submitted_revision, class_name: "Blog::Revision", optional: true
    belongs_to :approved_revision, class_name: "Blog::Revision", optional: true
    belongs_to :scheduled_revision, class_name: "Blog::Revision", optional: true
    has_many :revisions, dependent: :destroy
    has_many :paths, dependent: :destroy

    # Rails upper-cases percent-encoding in request paths, so stored paths must match.
    normalizes :path, with: ->(path) { Publication.normalize_path(path) }
    normalizes :canonical_url, with: ->(url) { url.strip }

    validates :topic_id, uniqueness: true
    validates :path,
              presence: true,
              length: {
                maximum: MAX_PATH_LENGTH,
              },
              format: {
                with: PATH_PATTERN,
              }
    validates :excerpt, length: { maximum: 1000 }, exclusion: { in: [nil] }
    validates :meta_description, length: { maximum: 500 }, exclusion: { in: [nil] }
    validates :canonical_url, length: { maximum: 1000 }, exclusion: { in: [nil] }
    validate :absolute_canonical_url
    validates :featured, inclusion: { in: [true, false] }
    validate :available_path
    validate :decodable_path
    validate :valid_publication_date
    before_validation :initialize_topics, on: :create
    before_save :capture_live_article, if: :will_save_change_to_published_revision_id?
    after_create :capture_initial_publication

    scope :newest, -> { order(published_at: :desc, id: :desc) }

    def self.publicly_visible
      return none unless Configuration.public_enabled?
      topics = Topic.secured.visible.listable_topics.where(category_id: SiteSetting.blog_category)
      topics = topics.where.not(id: Category.select(:topic_id).where.not(topic_id: nil))
      topics = topics.where.not(id: SharedDraft.select(:topic_id))
      joins(:published_revision, discussion_topic: :first_post)
        .where(published: true, discussion_topic_id: topics.select(:id))
        .where("blog_publications.published_at <= ?", Time.current)
        .where(posts: { hidden: false, deleted_at: nil, post_type: Post.types[:regular] })
    end

    def self.for_topic(topic)
      where(topic_id: topic.id)
        .or(where(draft_topic_id: topic.id))
        .or(where(discussion_topic_id: topic.id))
        .first || new(topic: topic, path: default_path(topic))
    end

    # Editorial changes to an article serialize on its original topic's row.
    def self.lock_for_topic(topic)
      publication = for_topic(topic)
      publication.topic.lock!
      publication.persisted? ? publication.reload : publication
    end

    def self.lock_existing_for_topic(topic)
      publication = lock_for_topic(topic)
      publication if publication.persisted?
    end

    def self.editable_for(topic, guardian)
      return if !UpcomingChanges.enabled?(:blog_enabled)
      return if topic.private_message?
      categories = [SiteSetting.blog_category.to_i, SiteSetting.blog_drafts_category.to_i]
      return if categories.exclude?(topic.category_id)
      return if !guardian.is_blog_contributor?

      publication = for_topic(topic)
      publication if guardian.can_edit_blog_topic?(publication.editable_topic)
    end

    def self.default_path(topic, date: nil, slug: topic.slug)
      format = PathFormat.current
      slug = visible_slug(slug).presence || topic.id.to_s
      date ||= Time.current
      path = format.render(slug:, id: topic.id, date:, max_length: MAX_PATH_LENGTH)
      return path if !reserved_path?(path)

      format.render(slug: "#{slug}-#{topic.id}", id: topic.id, date:, max_length: MAX_PATH_LENGTH)
    end

    # Encoded topic slugs keep invisible characters from the title, which paths reject.
    def self.visible_slug(slug)
      return slug if !slug.to_s.include?("%")
      decoded = URI.decode_uri_component(slug)
      return "" if !decoded.valid_encoding?
      CGI
        .escape(decoded.gsub(HIDDEN_PATH_CHARACTERS, ""))
        .squeeze("-")
        .delete_prefix("-")
        .delete_suffix("-")
    rescue ArgumentError
      ""
    end

    def self.normalize_path(path)
      path.gsub(/%\h{2}/, &:upcase)
    end

    # Expects a path that already matches PATH_PATTERN.
    def self.decodable_path?(path)
      decoded = URI.decode_uri_component(path)
      decoded.valid_encoding? && !decoded.match?(HIDDEN_PATH_CHARACTERS)
    end

    def self.traversal_path?(path)
      path.to_s.split("/").intersect?(%w[. ..])
    end

    def self.reserved_path?(path)
      segments = path.to_s.downcase.split("/").drop(1)
      # Some blog routes accept an optional format, so "/about.json" resolves like "/about".
      names = [segments.first.to_s, segments.first.to_s.sub(/\.[^.]*\z/, "")]
      names.intersect?(RESERVED_SEGMENTS) ||
        (segments.size == 1 && names.intersect?(Routes::RESERVED_EXACT_SEGMENTS))
    end

    def publicly_visible?
      persisted? && self.class.publicly_visible.where(id: id).exists?
    end

    def editorial_topic
      draft_topic || (topic if topic.category_id == SiteSetting.blog_drafts_category.to_i)
    end

    def editable_topic
      editorial_topic || topic
    end

    def editorial_metadata
      values = attributes.slice(*METADATA).as_json.merge(draft_metadata)
      values["published_at"] ||= published_at&.iso8601
      values
    end

    # Names of the article pieces that differ between the working copy and the live revision.
    def pending_changes
      source = editorial_topic
      return [] unless published_revision && source&.first_post

      metadata = editorial_metadata
      live = published_revision.data
      changes = {
        "title" => source.title != published_revision.title,
        "body" => source.first_post.raw != published_revision.raw,
        "path" => metadata["path"] != live["path"],
        "excerpt" => metadata["excerpt"] != live["excerpt"],
        # Revisions from before these fields existed don't have them.
        "meta_description" => metadata["meta_description"].to_s != live["meta_description"].to_s,
        "canonical_url" => metadata["canonical_url"].to_s != live["canonical_url"].to_s,
        "featured" => metadata["featured"] != live["featured"],
        "tags" => source.tags.visible(Guardian.new).pluck(:name).sort != Array(live["tags"]).sort,
        "published_at" => draft_date_changed?(metadata["published_at"]),
        "revision" => submitted_revision_differs?,
      }
      changes.select { |_, changed| changed }.keys
    end

    def edits_since_publish
      source = editorial_topic
      return 0 unless last_published_at && source&.first_post
      PostRevision.where(post: source.first_post).where("created_at > ?", last_published_at).count
    end

    # The published revision, read from text columns so hostname and upload remaps reach it.
    def article
      return Revision.new(data: Revision.capture(self, editable_topic)) if !published_revision
      return published_revision if cooked.nil?
      Revision.new(
        data: published_revision.data.merge("cooked" => cooked, "image_url" => image_url),
      )
    end

    # Rebakes leave published articles alone, so bulk imports that rebake after
    # publishing copy the discussion post's new HTML across explicitly.
    def refresh_article!
      post = discussion_topic&.first_post
      return false if !published_revision_id || post.blank? || post.cooked.blank?
      update_columns(
        cooked: post.cooked,
        image_url: Revision.image_url_for(discussion_topic.image_upload),
      )
    end

    def url
      "#{Configuration.base_url}#{published_revision&.data&.fetch("path") || path}"
    end

    def preview_url
      "#{Discourse.base_url}/blog-editor/preview/#{topic_id}"
    end

    def display_excerpt
      article.data["excerpt"].presence ||
        PrettyText.excerpt(article.cooked.to_s, 240, strip_links: true, strip_tags: true)
    end

    def display_description
      article.data["meta_description"].presence || display_excerpt
    end

    # Syndicated articles point search engines at the original instead of the blog.
    def canonical_article_url
      published_revision&.data&.[]("canonical_url").presence || url
    end

    def article_updated_at
      last_published_at || published_at || updated_at
    end

    def stage_metadata(changes)
      changes = changes.to_h.stringify_keys.slice(*METADATA)
      staged = editorial_metadata
      values = staged.merge(changes)
      values["published_at"] = published_at if published_revision_id &&
        values["published_at"].blank?
      live = attributes.slice(*METADATA)
      assign_attributes(values.slice(*METADATA))
      custom_path = staged["custom_path"] || path != staged["path"]
      if !published_revision_id && changes.key?("published_at") && !custom_path
        self.path = generated_path(published_at) || path
      end
      return self if invalid?
      self.draft_metadata = attributes.slice(*METADATA).as_json.merge("custom_path" => custom_path)
      assign_attributes(live) if published_revision_id
      self
    end

    def draftable?
      return true if editorial_topic
      source = discussion_topic || topic
      return false if source.archived?
      return false if !source.first_post
      !source.first_post.hidden?
    end

    def publishable_source?(source)
      return false if !source.blog_editorial_draft?
      post = source.first_post
      return false if !post || post.deleted_at
      !post.hidden?
    end

    def copy_post!(creator, source, category_id)
      Blog::Current.set(copy_source_id: source.id, copy_category_id: category_id) do
        creator.create!
      end
    end

    def clear_schedule!(error: "")
      # Cleanup must succeed even when publication metadata is no longer valid.
      update_columns(
        scheduled_at: nil,
        scheduled_revision_id: nil,
        scheduler_id: nil,
        schedule_token: nil,
        schedule_error: error,
        updated_at: Time.current,
      )
    end

    # A first release renders a path the editor did not type from the approved title
    # and the date the article goes live.
    def release_revision(revision)
      return revision if published_revision_id || revision.data["custom_path"]
      path = generated_path(release_date(revision), title: revision.title) || revision.data["path"]
      return revision if path == revision.data["path"]

      successor =
        revisions.create!(
          source_topic: revision.source_topic,
          creator: revision.creator,
          approver: revision.approver,
          approved_at: revision.approved_at,
          data: revision.data.merge("path" => path),
        )
      self.submitted_revision = successor if submitted_revision_id == revision.id
      self.approved_revision = successor if approved_revision_id == revision.id
      if draft_metadata["path"] == revision.data["path"]
        self.draft_metadata = draft_metadata.merge("path" => path)
      end
      successor
    end

    def stage_release(revision, publisher)
      data = revision.data
      assign_attributes(
        path: data["path"],
        excerpt: data["excerpt"],
        meta_description: data["meta_description"].to_s,
        canonical_url: data["canonical_url"].to_s,
        featured: data["featured"],
        published_at: release_date(revision),
        last_published_at: Time.current,
        published_revision: revision,
        publisher:,
        published: true,
      )
      self
    end

    private

    def release_date(revision)
      date = revision.data["published_at"].presence
      (date && Time.zone.parse(date.to_s)) || published_at || Time.current
    end

    # Nil when another article already holds the address, so the current path stays.
    def generated_path(date, title: nil)
      source = editable_topic
      slug = title ? source.slug_for_topic(title) : source.slug
      generated = self.class.default_path(source, date:, slug:)
      generated if path_available?(generated)
    end

    def path_available?(candidate)
      !Path.where(path: candidate).where.not(publication_id: id).exists?
    end

    def draft_date_changed?(value)
      return false if value.blank?
      parsed =
        begin
          Time.zone.parse(value.to_s)
        rescue ArgumentError
          nil
        end
      parsed.present? && parsed.to_i != published_at&.to_i
    end

    # A re-submission of an unchanged draft is not a pending change.
    def submitted_revision_differs?
      return false if submitted_revision_id.blank? || submitted_revision_id == published_revision_id
      compared = %w[title raw path excerpt featured meta_description canonical_url]
      submitted_revision.data.values_at(*compared).map(&:to_s) !=
        published_revision.data.values_at(*compared).map(&:to_s)
    end

    def initialize_topics
      if topic.category_id == SiteSetting.blog_drafts_category.to_i
        self.draft_topic ||= topic
      elsif topic.category_id == SiteSetting.blog_category.to_i
        self.discussion_topic ||= topic
      end
    end

    def capture_live_article
      self.cooked = published_revision&.cooked
      self.image_url = published_revision&.data&.[]("image_url")
    end

    def capture_initial_publication
      return unless published? && discussion_topic && !published_revision_id
      revision =
        revisions.create!(
          source_topic: topic,
          creator: publisher || topic.user,
          approver: publisher || topic.user,
          approved_at: published_at,
          data: Revision.capture(self, topic),
        )
      update!(published_revision: revision, last_published_at: updated_at)
    end

    def available_path
      if reserved_path? || self.class.traversal_path?(path) || !path_available?(path)
        errors.add(:path, I18n.t("blog.errors.path_taken"))
      end
    end

    def absolute_canonical_url
      return if canonical_url.blank?
      uri =
        begin
          URI.parse(canonical_url)
        rescue URI::InvalidURIError
          nil
        end
      return if uri.is_a?(URI::HTTP) && uri.host.present?
      errors.add(:canonical_url, I18n.t("blog.errors.canonical_url_invalid"))
    end

    def decodable_path
      return if !path.to_s.match?(PATH_PATTERN) || self.class.decodable_path?(path)
      errors.add(:path, :invalid)
    end

    def reserved_path?
      # A segment reserved later must not invalidate an existing article.
      return false if persisted? && !will_save_change_to_path?
      # Dated archive imports may use the otherwise reserved editorial prefix.
      return false if path.to_s.match?(%r{\A/blog/archive/\d{4}/\d{2}/\d{2}/[^/]+\z})
      self.class.reserved_path?(path)
    end

    def valid_publication_date
      if (published? || published_at_before_type_cast.present?) && published_at.nil?
        errors.add(:published_at, :invalid)
      end
      if published_at && published_at > Time.current
        errors.add(:published_at, I18n.t("blog.errors.future_date"))
      end
    end
  end
end

# == Schema Information
#
# Table name: blog_publications
#
#  id                    :bigint           not null, primary key
#  canonical_url         :string           default(""), not null
#  cooked                :text
#  draft_metadata        :jsonb            not null
#  excerpt               :string           default(""), not null
#  featured              :boolean          default(FALSE), not null
#  image_url             :text
#  last_published_at     :datetime
#  meta_description      :string           default(""), not null
#  path                  :string           not null
#  published             :boolean          default(FALSE), not null
#  published_at          :datetime
#  schedule_error        :text             default(""), not null
#  schedule_token        :string
#  scheduled_at          :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  approved_revision_id  :bigint
#  discussion_topic_id   :bigint
#  draft_topic_id        :bigint
#  published_revision_id :bigint
#  publisher_id          :bigint
#  scheduled_revision_id :bigint
#  scheduler_id          :bigint
#  submitted_revision_id :bigint
#  topic_id              :bigint           not null
#
# Indexes
#
#  idx_blog_publications_scheduled_at                     (scheduled_at) WHERE (scheduled_at IS NOT NULL)
#  index_blog_publications_on_discussion_topic_id         (discussion_topic_id) UNIQUE
#  index_blog_publications_on_draft_topic_id              (draft_topic_id) UNIQUE
#  index_blog_publications_on_published_and_published_at  (published,published_at)
#  index_blog_publications_on_topic_id                    (topic_id) UNIQUE
#
