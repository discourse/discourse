# frozen_string_literal: true

class AiArtifact < ActiveRecord::Base
  has_many :versions, class_name: "AiArtifactVersion", dependent: :destroy
  has_many :key_values, class_name: "AiArtifactKeyValue", dependent: :destroy
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

  def self.share_publicly(id:, post:)
    artifact = AiArtifact.find_by(id: id)
    if artifact&.post&.topic&.id == post.topic.id
      artifact.metadata ||= {}
      artifact.metadata[:public] = true
      artifact.save!
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

  def public?
    !!metadata&.dig("public")
  end
end

# == Schema Information
#
# Table name: ai_artifacts
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  post_id    :integer          not null
#  name       :string(255)      not null
#  html       :string(65535)
#  css        :string(65535)
#  js         :string(65535)
#  metadata   :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
