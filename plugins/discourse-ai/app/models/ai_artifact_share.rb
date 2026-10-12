# frozen_string_literal: true

class AiArtifactShare < ActiveRecord::Base
  belongs_to :ai_artifact
  belongs_to :user
  has_many :key_values, class_name: "AiArtifactShareKeyValue", dependent: :destroy

  validates :share_key, presence: true, uniqueness: true
  validates :html, :css, :js, length: { maximum: 65_535 }

  before_validation :generate_share_key, on: :create

  # Snapshots outlive the settings and group membership that allowed publishing,
  # so public visibility is re-evaluated on every read rather than at publish time.
  def self.publicly_viewable_by?(user)
    return false if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_bot_enabled
    return false if !user

    allowed_group_ids = SiteSetting.ai_bot_public_sharing_allowed_groups_map
    return false if allowed_group_ids.empty?

    user.in_any_groups?(allowed_group_ids)
  end

  def publicly_visible?
    return false if !SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict])
    return false if !self.class.publicly_viewable_by?(User.find_by(id: user_id))

    post = ai_artifact&.post
    topic = post&.topic
    post && !post.deleted_at && topic && !topic.deleted_at
  end

  def url
    "#{Discourse.base_url}/discourse-ai/ai-bot/artifact-shares/#{share_key}"
  end

  def pin!(version_number:)
    update!(snapshot_attributes(version_number: version_number))
  end

  def snapshot_attributes(version_number:)
    source =
      if version_number == 0
        ai_artifact
      else
        ai_artifact.versions.find_by(version_number: version_number)
      end
    raise Discourse::NotFound if !source

    upload_roots =
      if SiteSetting.Upload.enable_s3_uploads
        [SiteSetting.Upload.s3_base_url, SiteSetting.Upload.s3_cdn_url].filter_map do |url|
          url.presence&.sub(/\Ahttps?:/, "")&.sub(%r{/+\z}, "")
        end
      else
        []
      end

    if [source.html, source.css, source.js].any? { |content|
         content = CGI.unescapeHTML(content.to_s)
         content.match?(%r{upload://|/(?:secure-(?:media-)?)?uploads/}i) ||
           upload_roots.any? do |root|
             content.match?(%r{(?:https?:)?#{Regexp.escape(root)}(?:/|[?#])}i)
           end
       }
      raise Discourse::InvalidAccess.new(
              nil,
              nil,
              custom_message: "discourse_ai.ai_artifact.uploads_cannot_be_shared",
            )
    end

    {
      name: ai_artifact.name,
      version_number: version_number,
      html: source.html,
      css: source.css,
      js: source.js,
    }
  end

  private

  def generate_share_key
    self.share_key ||= SecureRandom.urlsafe_base64(32)
  end
end

# == Schema Information
#
# Table name: ai_artifact_shares
#
#  id             :bigint           not null, primary key
#  css            :string(65535)
#  html           :string(65535)
#  js             :string(65535)
#  name           :string           not null
#  share_key      :string           not null
#  version_number :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ai_artifact_id :bigint           not null
#  user_id        :integer          not null
#
# Indexes
#
#  index_ai_artifact_shares_on_ai_artifact_id              (ai_artifact_id)
#  index_ai_artifact_shares_on_share_key                   (share_key) UNIQUE
#  index_ai_artifact_shares_on_user_id_and_ai_artifact_id  (user_id,ai_artifact_id) UNIQUE
#  index_ai_artifact_shares_on_user_id_and_created_at      (user_id,created_at)
#
