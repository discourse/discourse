# frozen_string_literal: true

class AiArtifact < ActiveRecord::Base
  has_many :versions, class_name: "AiArtifactVersion", dependent: :destroy
  has_many :key_values, class_name: "AiArtifactKeyValue", dependent: :destroy
  has_many :shares, class_name: "AiArtifactShare", dependent: :destroy
  belongs_to :user
  belongs_to :post
  validates :html, length: { maximum: 65_535 }
  validates :css, length: { maximum: 65_535 }
  validates :js, length: { maximum: 65_535 }

  ALLOWED_CDN_SOURCES = %w[
    https://cdn.jsdelivr.net
    https://cdnjs.cloudflare.com
    https://unpkg.com
    https://ajax.googleapis.com
    https://d3js.org
    https://code.jquery.com
    https://esm.sh
  ]

  def self.artifact_version_attribute(version)
    if version
      "data-artifact-version='#{version}'"
    else
      ""
    end
  end

  def self.iframe_for(id, version = nil)
    <<~HTML
      <div class='ai-artifact'>
        <iframe src='#{url(id, version)}' frameborder="0" height="100%" width="100%"></iframe>
        <div class='ai-artifact-controls'>
          <a href='#{url(id, version)}' class='link-artifact' target='_blank'>#{I18n.t("discourse_ai.ai_artifact.link")}</a>
          <a href class='copy-embed' data-artifact-id="#{id}" #{artifact_version_attribute(version)} data-url="#{url(id, version)}">#{I18n.t("discourse_ai.ai_artifact.copy_embed")}</a>
        </div>
      </div>
    HTML
  end

  def self.url(id, version = nil)
    url = Discourse.base_url + "/discourse-ai/ai-bot/artifacts/#{id}"
    if version
      "#{url}/#{version}"
    else
      url
    end
  end

  def self.embed_url(id, version = nil)
    path = "#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{id}"
    version ? "#{path}/#{version}/embed" : "#{path}/embed"
  end

  def self.share_publicly(id:, post:)
    artifact = AiArtifact.find_by(id: id)
    return if !artifact

    artifact.with_lock do
      if artifact.post&.topic_id == post.topic_id
        artifact.metadata ||= {}
        artifact.metadata[:public] = true
        artifact.save!
      end
    end
  end

  def self.publicly_available_in(topic, post_ids: nil)
    guest = Guardian.new
    if guest.can_see?(topic)
      posts = topic.posts.secured(guest).where(hidden: false)
      posts = posts.where(id: post_ids) if post_ids
      return where(post_id: posts.select(:id))
    end

    conversation = SharedAiConversation.find_by(target: topic)
    return none if !conversation&.publicly_visible?

    artifacts = where(post_id: topic.posts.select(:id))
    if post_ids
      context_ids = conversation.context.filter_map { |post| post["id"] } & post_ids
      invalidates_share = topic.posts.where(id: context_ids).where.not(post_number: 1).exists?
      artifacts = artifacts.where(post_id: post_ids) if !invalidates_share
    end
    published_ids = conversation.context.flat_map { |post| Array(post["artifact_ids"]) }
    artifacts.where(id: published_ids).where("metadata->>'public' = 'true'")
  end

  def self.handle_posts_move(
    destination_topic_id:,
    original_topic_id:,
    post_id_map:,
    preserve_original: false
  )
    return if preserve_original || post_id_map.blank?

    artifacts = where(post_id: post_id_map.keys).select(:id, :post_id).to_a
    return if artifacts.empty?

    artifacts.each do |artifact|
      new_post_id = post_id_map.fetch(artifact.post_id)
      artifact.update_columns(post_id: new_post_id) if new_post_id != artifact.post_id
    end
    destination = Topic.find(destination_topic_id)
    return if Guardian.new.can_see?(destination)

    artifact_ids = artifacts.map(&:id)
    where(id: artifact_ids).update_all(
      "metadata = jsonb_set(COALESCE(metadata, '{}'), '{public}', 'false')",
    )
    SharedAiConversation
      .where(target_type: "Topic", target_id: [original_topic_id, destination_topic_id])
      .order(:id)
      .lock
      .each do |conversation|
        context =
          conversation.context.map do |context_post|
            ids = context_post["artifact_ids"]
            if ids.is_a?(Array) && ids.intersect?(artifact_ids)
              context_post.merge("artifact_ids" => ids - artifact_ids)
            else
              context_post
            end
          end
        conversation.update_columns(context: context) if context != conversation.context
      end
  end

  def self.unshare_publicly(id:)
    artifact = AiArtifact.find_by(id: id)
    artifact&.update!(metadata: { public: false })
  end

  def url
    self.class.url(id)
  end

  def apply_diff(html_diff: nil, css_diff: nil, js_diff: nil, change_description: nil)
    differ = DiscourseAi::Utils::DiffUtils

    html = html_diff ? differ.apply_hunk(self.html, html_diff) : self.html
    css = css_diff ? differ.apply_hunk(self.css, css_diff) : self.css
    js = js_diff ? differ.apply_hunk(self.js, js_diff) : self.js

    create_new_version(html: html, css: css, js: js, change_description: change_description)
  end

  def create_new_version(html: nil, css: nil, js: nil, change_description: nil)
    latest_version = versions.order(version_number: :desc).first
    new_version_number = latest_version ? latest_version.version_number + 1 : 1
    version = nil

    transaction do
      # Create the version record
      version =
        versions.create!(
          version_number: new_version_number,
          html: html || self.html,
          css: css || self.css,
          js: js || self.js,
          change_description: change_description,
        )
      save!
    end

    version
  end

  def available_to?(guardian)
    if !SiteSetting.discourse_ai_enabled ||
         !SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict])
      return false
    end

    source_post = Post.find_by(id: post_id)
    return false if source_post.blank? || source_post.topic.blank?

    return true if public? && covered_by_public_conversation_share?(source_post)

    guardian.can_see?(source_post)
  end

  def publicly_embeddable?
    if !SiteSetting.discourse_ai_enabled ||
         !SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict])
      return false
    end

    source_post = Post.find_by(id: post_id)
    topic = source_post&.topic
    return false if !topic || source_post.deleted_at || topic.deleted_at
    return true if Guardian.new(nil).can_see?(source_post)
    return false if !public?

    covered_by_public_conversation_share?(source_post)
  end

  def public?
    metadata&.dig("public") == true
  end

  private

  def covered_by_public_conversation_share?(source_post)
    conversation = SharedAiConversation.find_by(target: source_post.topic)
    conversation&.publishes_artifact?(id) && conversation.publicly_visible?
  end
end

# == Schema Information
#
# Table name: ai_artifacts
#
#  id         :bigint           not null, primary key
#  css        :string(65535)
#  html       :string(65535)
#  js         :string(65535)
#  metadata   :jsonb
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer          not null
#  user_id    :integer          not null
#
