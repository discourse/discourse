# frozen_string_literal: true

module ::Blog
  class Publication < ActiveRecord::Base
    self.table_name = "blog_publications"
    RESERVED_PATHS =
      (
        %w[
          about
          tag
          feed
          feed.xml
          sitemap
          sitemap.xml
          robots
          robots.txt
          blog
          session
          admin
          t
          u
          review
          posts
          posts.rss
          posts.atom
          blog-theme.css
          blog-custom.js
          blog-highlight
        ] + Configuration::ASSET_PREFIXES
      ).freeze
    METADATA = %w[path excerpt featured published_at].freeze

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

    validates :topic_id, uniqueness: true
    validates :path,
              presence: true,
              length: {
                maximum: 240,
              },
              format: {
                with: %r{\A/(?:[a-zA-Z0-9_+.,-]|%2[bBcC])+(?:/(?:[a-zA-Z0-9_+.,-]|%2[bBcC])+)*\z},
              }
    validates :excerpt, length: { maximum: 1000 }, exclusion: { in: [nil] }
    validates :featured, inclusion: { in: [true, false] }
    validate :available_path
    validate :valid_publication_date
    before_validation :initialize_topics, on: :create
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
        .first || new(topic: topic, path: "/#{topic.slug.presence || topic.id}")
    end

    def publicly_visible?
      persisted? && self.class.publicly_visible.where(id: id).exists?
    end

    def editorial_topic
      draft_topic || (topic if topic.category_id == SiteSetting.blog_drafts_category.to_i)
    end

    def editorial_metadata
      values = attributes.slice(*METADATA).as_json.merge(draft_metadata)
      values["published_at"] ||= published_at&.iso8601
      values
    end

    def draft_correction?
      pending_changes.any?
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
        "featured" => metadata["featured"] != live["featured"],
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

    def article
      published_revision || Revision.new(data: Revision.capture(self, editorial_topic || topic))
    end

    def url
      "#{Configuration.origin}#{published_revision&.data&.fetch("path") || path}"
    end

    def preview_url
      "#{Discourse.base_url}/blog/preview/#{topic_id}"
    end

    def display_excerpt
      article.data["excerpt"].presence ||
        PrettyText.excerpt(article.cooked.to_s, 240, strip_links: true, strip_tags: true)
    end

    def article_updated_at
      last_published_at || published_at || updated_at
    end

    def save_metadata!(user, attributes)
      Configuration.ensure_ready!
      topic.with_lock do
        reload if persisted?
        Configuration.ensure_editor!(user, editorial_topic || topic)
        values = editorial_metadata.merge(attributes.to_h.stringify_keys.slice(*METADATA))
        values["published_at"] = published_at if published_revision_id &&
          values["published_at"].blank?
        previous = self.attributes.slice(*METADATA)
        assign_attributes(values)
        raise ActiveRecord::RecordInvalid.new(self) unless valid?
        self.draft_metadata = self.attributes.slice(*METADATA).as_json
        assign_attributes(previous) if published_revision_id
        save!
        StaffActionLogger.new(user).log_custom(
          "blog_metadata",
          topic_id: topic_id,
          path: values["path"],
        )
      end
      self
    end

    def prepare_draft!(user)
      Configuration.ensure_ready!
      topic.with_lock do
        reload if persisted?
        Configuration.ensure_editor!(user, editorial_topic || topic)
        save! unless persisted?
        unless editorial_topic
          source = discussion_topic || topic
          unless source.first_post && !source.first_post.hidden? && !source.archived?
            raise Discourse::InvalidAccess
          end
          creator =
            PostCreator.new(
              source.user || user,
              title: source.title,
              raw: source.first_post.raw,
              tags: source.tags.visible(Guardian.new).pluck(:name),
              category: SiteSetting.blog_drafts_category.to_i,
              guardian: user.guardian,
              acting_user: user,
              skip_jobs: true,
            )
          post = copy_post!(creator, source, SiteSetting.blog_drafts_category.to_i)
          post.topic.update!(image_upload_id: source.image_upload_id)
          update!(draft_topic: post.topic)
          DB.after_commit { creator.enqueue_jobs }
        end
        update!(draft_topic: editorial_topic) unless draft_topic_id
      end
      editorial_topic
    end

    def submit!(user)
      source = prepare_draft!(user)
      topic.with_lock do
        reload
        source.with_lock do
          Configuration.ensure_editor!(user, source)
          ensure_source!(source)
          source.first_post.with_lock do
            revision =
              revisions.create!(
                source_topic: source,
                creator: user,
                data: Revision.capture(self, source),
              )
            update!(submitted_revision: revision, approved_revision: nil)
          end
        end
        StaffActionLogger.new(user).log_custom(
          "blog_submit",
          topic_id: topic_id,
          revision_id: submitted_revision_id,
        )
      end
      submitted_revision
    end

    def approve!(user, revision_id)
      topic.with_lock do
        reload
        Configuration.ensure_publisher!(user, editorial_topic || topic)
        revision = revisions.find(revision_id)
        unless revision.id == submitted_revision_id
          raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.stale"))
        end
        revision.update!(approver: user, approved_at: Time.current) unless revision.approved_at
        update!(approved_revision: revision)
        StaffActionLogger.new(user).log_custom(
          "blog_approve",
          topic_id: topic_id,
          revision_id: revision.id,
        )
      end
      self
    end

    def publish!(user, revision_id: nil)
      # Trusted callers can explicitly approve and publish their current draft in one operation.
      unless revision_id
        revision = submit!(user)
        approve!(user, revision.id)
        revision_id = revision.id
      end
      topic.with_lock do
        reload
        revision = revisions.find(revision_id)
        Configuration.ensure_publisher!(user, editorial_topic || topic)
        unless approved_revision_id == revision.id
          raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.stale"))
        end
        publish_revision!(user, revision)
        clear_schedule!
      end
      self
    end

    def schedule!(user, revision_id:, at:)
      time =
        begin
          Time.zone.parse(at.to_s)
        rescue ArgumentError
          nil
        end
      unless time && time > 1.minute.from_now && time <= 1.year.from_now
        raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.schedule_time"))
      end
      topic.with_lock do
        reload
        Configuration.ensure_ready!
        Configuration.ensure_publisher!(user, editorial_topic || topic)
        revision = revisions.find(revision_id)
        unless approved_revision_id == revision.id && revision.approved_at
          raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.approval_required"))
        end
        update!(
          scheduled_revision: revision,
          scheduled_at: time,
          scheduler: user,
          schedule_token: SecureRandom.uuid,
          schedule_error: "",
        )
        token = schedule_token
        DB.after_commit do
          Jobs.enqueue_at(time, :publish_blog_revision, publication_id: id, token: token)
        end
        StaffActionLogger.new(user).log_custom(
          "blog_schedule",
          topic_id: topic_id,
          revision_id: revision.id,
          scheduled_at: time,
        )
      end
      self
    end

    def cancel_schedule!(user)
      topic.with_lock do
        reload
        Configuration.ensure_publisher!(user, editorial_topic || topic)
        clear_schedule!
      end
    end

    def run_schedule!(token)
      topic.with_lock do
        reload
        return unless schedule_token == token && scheduled_at && scheduled_at <= Time.current
        begin
          self
            .class
            .transaction(requires_new: true) { publish_revision!(scheduler, scheduled_revision) }
          clear_schedule!
        rescue Discourse::InvalidAccess,
               Discourse::InvalidParameters,
               ActiveRecord::RecordInvalid,
               ActiveRecord::RecordNotSaved => error
          reload
          clear_schedule!(
            error:
              (
                if error.is_a?(Discourse::InvalidAccess)
                  I18n.t("blog.editorial.access_lost")
                else
                  error.message
                end
              ).first(500),
          )
        end
      end
    end

    def unpublish!(user)
      topic.with_lock do
        reload
        Configuration.ensure_publisher!(user, editorial_topic || topic)
        update!(published: false)
        clear_schedule!
        StaffActionLogger.new(user).log_custom("blog_unpublish", topic_id: topic_id)
      end
    end

    def return_to_drafts!(user)
      unpublish!(user)
      prepare_draft!(user)
    end

    private

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
      compared = %w[title raw path excerpt featured]
      submitted_revision.data.slice(*compared) != published_revision.data.slice(*compared)
    end

    def initialize_topics
      if topic.category_id == SiteSetting.blog_drafts_category.to_i
        self.draft_topic ||= topic
      elsif topic.category_id == SiteSetting.blog_category.to_i
        self.discussion_topic ||= topic
      end
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

    def ensure_source!(source)
      if source.deleted_at || source.archived? || source.shared_draft? || !source.visible ||
           source.category_id != SiteSetting.blog_drafts_category.to_i || !source.first_post ||
           source.first_post.deleted_at || source.first_post.hidden?
        raise Discourse::InvalidAccess
      end
    end

    def publish_revision!(user, revision)
      Configuration.ensure_ready!
      source = editorial_topic
      unless source && revision&.approved_at && revision.publication_id == id
        raise Discourse::InvalidAccess
      end
      ensure_source!(source)
      Configuration.ensure_publisher!(user, source)
      Configuration.ensure_publisher!(revision.approver, source)
      user.guardian.ensure_can_create_topic_on_category!(SiteSetting.blog_category.to_i)
      if PublishedPage.exists?(topic_id: source.id)
        raise Discourse::InvalidParameters.new(I18n.t("blog.errors.published_page"))
      end
      data = revision.data
      if discussion_topic
        user.guardian.ensure_can_see!(discussion_topic)
        if discussion_topic.deleted_at || discussion_topic.archived? ||
             discussion_topic.shared_draft? || !discussion_topic.visible ||
             !discussion_topic.first_post || discussion_topic.first_post.hidden? ||
             discussion_topic.category_id != SiteSetting.blog_category.to_i
          raise Discourse::InvalidAccess
        end
        previous = Thread.current[:blog_publishing_topic]
        begin
          Thread.current[:blog_publishing_topic] = discussion_topic_id
          unless PostRevisor.new(discussion_topic.first_post).revise!(
                   user,
                   { raw: data["raw"], title: data["title"], tags: data["tags"] },
                   force_new_version: true,
                 )
            raise ActiveRecord::RecordInvalid.new(discussion_topic.first_post)
          end
        ensure
          Thread.current[:blog_publishing_topic] = previous
        end
      else
        creator =
          PostCreator.new(
            source.user || user,
            raw: data["raw"],
            title: data["title"],
            tags: data["tags"],
            category: SiteSetting.blog_category.to_i,
            guardian: user.guardian,
            acting_user: user,
            skip_jobs: true,
          )
        post = copy_post!(creator, source, SiteSetting.blog_category.to_i)
        self.discussion_topic = post.topic
        DB.after_commit { creator.enqueue_jobs }
      end
      self.path = data["path"]
      self.excerpt = data["excerpt"]
      self.featured = data["featured"]
      self.published_at = data["published_at"].presence || published_at || Time.current
      self.last_published_at = Time.current
      self.published_revision = revision
      self.publisher = user
      self.published = true
      save!
      paths.find_or_create_by!(path: path)
      Review.revoke_for_topic!(source.id)
      StaffActionLogger.new(user).log_custom(
        "blog_publish",
        topic_id: discussion_topic_id,
        revision_id: revision.id,
      )
    end

    def copy_post!(creator, source, category_id)
      previous = Thread.current[:blog_copy]
      Thread.current[:blog_copy] = { source_id: source.id, category_id: category_id }
      creator.create!
    ensure
      Thread.current[:blog_copy] = previous
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

    def available_path
      segments = path.to_s.split("/")
      # Dated archive imports may use the otherwise reserved editorial prefix.
      legacy_archive = path.to_s.match?(%r{\A/blog/archive/\d{4}/\d{2}/\d{2}/[^/]+\z})
      reserved = RESERVED_PATHS.include?(segments[1].to_s.downcase) && !legacy_archive
      if path.to_s.downcase == "/archive" || reserved || segments.intersect?(%w[. ..]) ||
           Path.where(path: path).where.not(publication_id: id).exists?
        errors.add(:path, I18n.t("blog.errors.path_taken"))
      end
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
#  draft_metadata        :jsonb            not null
#  excerpt               :string           default(""), not null
#  featured              :boolean          default(FALSE), not null
#  last_published_at     :datetime
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
