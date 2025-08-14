# frozen_string_literal: true

class AiArtifactSerializer < ApplicationSerializer
  attributes :id, :user_id, :post_id, :name, :html, :css, :js, :metadata, :created_at, :updated_at

  self.root = "ai_artifact"
end
