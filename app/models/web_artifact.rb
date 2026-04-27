# frozen_string_literal: true

class WebArtifact < ActiveRecord::Base
  has_many :versions, class_name: "WebArtifactVersion", dependent: :destroy
  has_many :key_values, class_name: "WebArtifactKeyValue", dependent: :destroy
  belongs_to :user
  belongs_to :post, optional: true
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
      <div class='web-artifact'>
        <iframe src='#{url(id, version)}' frameborder="0" height="100%" width="100%"></iframe>
        <div class='web-artifact-controls'>
          <a href='#{url(id, version)}' class='link-artifact' target='_blank'>#{I18n.t("web_artifact.link")}</a>
          <a href class='copy-embed' data-artifact-id="#{id}" #{artifact_version_attribute(version)} data-url="#{url(id, version)}">#{I18n.t("web_artifact.copy_embed")}</a>
        </div>
      </div>
    HTML
  end

  def self.url(id, version = nil)
    url = Discourse.base_url + "/w/#{id}"
    if version
      "#{url}/#{version}"
    else
      url
    end
  end

  def self.share_publicly(id:, post:)
    artifact = WebArtifact.find_by(id: id)
    if artifact&.post&.topic&.id == post.topic.id
      artifact.metadata ||= {}
      artifact.metadata[:public] = true
      artifact.save!
    end
  end

  def self.unshare_publicly(id:)
    artifact = WebArtifact.find_by(id: id)
    artifact&.update!(metadata: { public: false })
  end

  def url
    self.class.url(id)
  end

  def create_new_version(html: nil, css: nil, js: nil, change_description: nil)
    latest_version = versions.order(version_number: :desc).first
    new_version_number = latest_version ? latest_version.version_number + 1 : 1
    version = nil

    transaction do
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

  def self.link_artifacts_from_cooked(doc, post)
    artifact_ids =
      doc.css("div.web-artifact").map { |node| node["data-web-artifact-id"].to_i }.reject(&:zero?)

    return if artifact_ids.empty?

    WebArtifact.where(id: artifact_ids, user_id: post.user_id, post_id: nil).update_all(
      post_id: post.id,
    )
  end
end

# == Schema Information
#
# Table name: web_artifacts
#
#  id         :bigint           not null, primary key
#  css        :string(65535)
#  html       :string(65535)
#  js         :string(65535)
#  metadata   :jsonb
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  post_id    :integer
#  user_id    :integer          not null
#
