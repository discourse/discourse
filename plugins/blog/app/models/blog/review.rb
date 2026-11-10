# frozen_string_literal: true

module ::Blog
  class Review < ActiveRecord::Base
    include HasPostUploadReferences

    self.table_name = "blog_reviews"
    TOKEN_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
    LIFETIME = 7.days
    MAX_ACTIVE_PER_TOPIC = 20
    MAX_FEEDBACK = 200
    MAX_SNAPSHOT_BYTES = 1.megabyte

    belongs_to :topic
    belongs_to :creator, class_name: "User"
    has_many :feedback, class_name: "Blog::ReviewFeedback", dependent: :delete_all
    has_many :upload_references, as: :target, dependent: :destroy

    after_create :link_post_uploads
    after_update :release_uploads, if: -> { saved_change_to_revoked_at? && revoked_at? }

    validates :label, length: { maximum: 100 }
    validates :title, :cooked, :post_version, :expires_at, presence: true
    validates :token, format: { with: TOKEN_FORMAT }
    scope :unexpired, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

    def self.find_by_token!(token)
      raise Discourse::NotFound unless token.is_a?(String) && token.match?(TOKEN_FORMAT)
      review = unexpired.find_by(token: token)
      raise Discourse::NotFound unless review&.accessible?
      review
    end

    # Publishing closes the draft's links; the article is public by then, so its URL is safe to share.
    def self.published_article_url(token)
      return if !token.is_a?(String) || !token.match?(TOKEN_FORMAT)

      review = find_by(token: token, revoked_by_publish: true)
      return if !review

      publication = publication_for_reviewed_topic(review.topic_id)
      publication.url if publication&.publicly_visible?
    end

    # The reviewed topic is the publication's working copy, or its source before a copy existed.
    def self.publication_for_reviewed_topic(topic_id)
      Publication.where(draft_topic_id: topic_id).or(Publication.where(topic_id: topic_id)).first
    end
    private_class_method :publication_for_reviewed_topic

    # The link only reaches editors, who can already read the draft and issue more links.
    def url
      "#{Configuration.review_url}?#{{ review_token: token }.to_query}"
    end

    def self.eligible_topic?(topic)
      return false if !Configuration.public_enabled?
      return false if !listed_topic?(topic)
      return false if !private_draft?(topic)
      return false if !intact_post?(topic.first_post)
      !published_discussion?(topic)
    end

    def self.listed_topic?(topic)
      topic.present? && !topic.deleted_at && topic.visible
    end
    private_class_method :listed_topic?

    def self.private_draft?(topic)
      topic.category_id == SiteSetting.blog_drafts_category.to_i &&
        topic.category&.read_restricted? && !topic.private_message? && !topic.shared_draft?
    end
    private_class_method :private_draft?

    def self.intact_post?(post)
      post.present? && !post.deleted_at && !post.hidden?
    end
    private_class_method :intact_post?

    def self.published_discussion?(topic)
      Publication.where(discussion_topic_id: topic.id, published: true).exists?
    end
    private_class_method :published_discussion?

    def current?
      !revoked_at && expires_at > Time.current
    end

    def accessible?
      current? && self.class.eligible_topic?(topic) && self.class.creator_allowed?(creator, topic)
    end

    def self.creator_allowed?(creator, topic)
      return false unless creator&.active? && !creator.suspended?
      creator.guardian.can_edit_blog_topic?(topic)
    end

    def self.accessible_ids(reviews, topic)
      return [] if !eligible_topic?(topic)
      allowed_creator_ids =
        reviews.map(&:creator).uniq.select { |creator| creator_allowed?(creator, topic) }.map(&:id)
      reviews.filter_map do |review|
        review.id if review.current? && allowed_creator_ids.include?(review.creator_id)
      end
    end

    def self.revoke_for_topic!(topic_id, by_publish: false)
      transaction do
        where(topic_id: topic_id, revoked_at: nil).update_all(
          revoked_at: Time.current,
          revoked_by_publish: by_publish,
        )
        UploadReference.where(target: where(topic_id: topic_id)).delete_all
      end
    end

    def self.release_inactive_uploads!
      inactive = where.not(revoked_at: nil).or(where("expires_at <= ?", Time.current))
      UploadReference.where(target: inactive).delete_all
    end

    def self.snapshot_html(post)
      doc = Nokogiri::HTML5.fragment(PrettyText.sanitize(ArticleHtml.render(post.cooked)))
      doc.css("script, iframe, object, embed, form, input, button, style, link, meta").remove
      doc.css("a").each { |link| link["rel"] = "noopener noreferrer" }
      doc.to_html
    end

    private

    def release_uploads
      upload_references.delete_all
    end
  end
end

# == Schema Information
#
# Table name: blog_reviews
#
#  id                 :bigint           not null, primary key
#  cooked             :text             not null
#  expires_at         :datetime         not null
#  label              :string(100)      default(""), not null
#  post_version       :integer          not null
#  revoked_at         :datetime
#  revoked_by_publish :boolean          default(FALSE), not null
#  title              :string           not null
#  token              :string(64)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  creator_id         :bigint           not null
#  topic_id           :bigint           not null
#
# Indexes
#
#  index_blog_reviews_on_token                    (token) UNIQUE
#  index_blog_reviews_on_topic_id_and_created_at  (topic_id,created_at)
#
