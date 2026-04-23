# frozen_string_literal: true

class WebArtifactVersion < ActiveRecord::Base
  belongs_to :web_artifact
  validates :html, length: { maximum: 65_535 }
  validates :css, length: { maximum: 65_535 }
  validates :js, length: { maximum: 65_535 }
end

# == Schema Information
#
# Table name: web_artifact_versions
#
#  id                 :bigint           not null, primary key
#  change_description :string
#  css                :string(65535)
#  html               :string(65535)
#  js                 :string(65535)
#  metadata           :jsonb
#  version_number     :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  web_artifact_id    :bigint           not null
#
# Indexes
#
#  index_web_artifact_versions_unique  (web_artifact_id,version_number) UNIQUE
#
