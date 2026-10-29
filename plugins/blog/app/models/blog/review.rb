# frozen_string_literal: true

module ::Blog
  class Review < ActiveRecord::Base
    include HasPostUploadReferences

    self.table_name = "blog_reviews"
    TOKEN_FORMAT = /\A[A-Za-z0-9_-]{43}\z/

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

    def self.issue!(topic:, user:, label: "")
      topic.with_lock do
        Configuration.ensure_ready!
        Configuration.ensure_editor!(user, topic)
        raise Discourse::InvalidAccess unless eligible_topic?(topic)
        if where(topic_id: topic.id).unexpired.count >= 20
          raise Discourse::InvalidParameters.new(I18n.t("blog.review.limit"))
        end
        post = topic.first_post
        post.with_lock do
          raise Discourse::InvalidAccess unless eligible_topic?(topic)
          review =
            create!(
              topic: topic,
              creator: user,
              label: label,
              title: topic.title,
              cooked: snapshot_html(post),
              post_version: post.version,
              token: SecureRandom.urlsafe_base64(32),
              expires_at: 7.days.from_now,
            )
          StaffActionLogger.new(user).log_custom(
            "blog_review_create",
            topic_id: topic.id,
            review_id: review.id,
          )
          review
        end
      end
    end

    def self.find_by_token!(token)
      raise Discourse::NotFound unless token.is_a?(String) && token.match?(TOKEN_FORMAT)
      review = unexpired.find_by(token: token)
      raise Discourse::NotFound unless review&.accessible?
      review
    end

    # The link only reaches editors, who can already read the draft and issue more links.
    def url
      "#{Configuration.origin}/review?#{{ review_token: token }.to_query}"
    end

    def self.eligible_topic?(topic)
      Configuration.public_enabled? && topic.present? && !topic.deleted_at && topic.visible &&
        topic.category_id == SiteSetting.blog_drafts_category.to_i &&
        topic.category&.read_restricted? && !topic.private_message? && !topic.shared_draft? &&
        topic.first_post.present? && !topic.first_post.deleted_at && !topic.first_post.hidden? &&
        !Publication.where(discussion_topic_id: topic.id, published: true).exists?
    end

    def current?
      !revoked_at && expires_at > Time.current
    end

    def accessible?
      current? && self.class.eligible_topic?(topic) && self.class.creator_allowed?(creator, topic)
    end

    def self.creator_allowed?(creator, topic)
      return false unless creator&.active? && !creator.suspended?
      Configuration.ensure_editor!(creator, topic)
      true
    rescue Discourse::InvalidAccess
      false
    end

    def submit_feedback!(attributes)
      topic.with_lock do
        with_lock do
          raise Discourse::NotFound unless accessible?
          if feedback.count >= 200
            raise Discourse::InvalidParameters.new(I18n.t("blog.review.feedback_limit"))
          end
          feedback.create!(attributes)
        end
      end
    end

    def revoke!(user)
      topic.with_lock do
        Configuration.ensure_editor!(user, topic)
        update!(revoked_at: Time.current) unless revoked_at
        StaffActionLogger.new(user).log_custom(
          "blog_review_revoke",
          topic_id: topic_id,
          review_id: id,
        )
      end
    end

    def self.revoke_for_topic!(topic_id)
      transaction do
        where(topic_id: topic_id, revoked_at: nil).update_all(revoked_at: Time.current)
        UploadReference.where(target: where(topic_id: topic_id)).delete_all
      end
    end

    def self.release_inactive_uploads!
      inactive = where.not(revoked_at: nil).or(where("expires_at <= ?", Time.current))
      UploadReference.where(target: inactive).delete_all
    end

    def self.snapshot_html(post)
      helper = Object.new.extend(BlogHelper)
      doc = Nokogiri::HTML5.fragment(PrettyText.sanitize(helper.blog_article_html(post)))
      doc.css("script, iframe, object, embed, form, input, button, style, link, meta").remove
      doc.css("a").each { |link| link["rel"] = "noopener noreferrer" }
      html = doc.to_html
      raise Discourse::InvalidParameters.new(:cooked) if html.bytesize > 1_048_576
      html
    end
    private_class_method :snapshot_html

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
#  id           :bigint           not null, primary key
#  cooked       :text             not null
#  expires_at   :datetime         not null
#  label        :string(100)      default(""), not null
#  post_version :integer          not null
#  revoked_at   :datetime
#  title        :string           not null
#  token        :string(64)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  creator_id   :bigint           not null
#  topic_id     :bigint           not null
#
# Indexes
#
#  index_blog_reviews_on_token                    (token) UNIQUE
#  index_blog_reviews_on_topic_id_and_created_at  (topic_id,created_at)
#
