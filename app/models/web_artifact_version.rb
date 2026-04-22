# frozen_string_literal: true

class WebArtifactVersion < ActiveRecord::Base
  belongs_to :web_artifact
  validates :html, length: { maximum: 65_535 }
  validates :css, length: { maximum: 65_535 }
  validates :js, length: { maximum: 65_535 }
end
