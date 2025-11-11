# frozen_string_literal: true
class AiArtifactVersion < ActiveRecord::Base
  belongs_to :ai_artifact
  validates :html, length: { maximum: 65_535 }
  validates :css, length: { maximum: 65_535 }
  validates :js, length: { maximum: 65_535 }

  # used when generating test cases
  def write_to(path)
    css_path = "#{path}/main.css"
    html_path = "#{path}/main.html"
    js_path = "#{path}/main.js"
    instructions_path = "#{path}/instructions.txt"

    File.write(css_path, css)
    File.write(html_path, html)
    File.write(js_path, js)
    File.write(instructions_path, change_description)
  end
end

# == Schema Information
#
# Table name: ai_artifact_versions
#
#  id                 :bigint           not null, primary key
#  ai_artifact_id     :bigint           not null
#  version_number     :integer          not null
#  html               :string(65535)
#  css                :string(65535)
#  js                 :string(65535)
#  metadata           :jsonb
#  change_description :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_ai_artifact_versions_on_ai_artifact_id_and_version_number  (ai_artifact_id,version_number) UNIQUE
#
