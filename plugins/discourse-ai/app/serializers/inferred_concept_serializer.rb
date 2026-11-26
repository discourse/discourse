# frozen_string_literal: true

class InferredConceptSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :slug,
             :description,
             :status,
             :aliases,
             :parent_id,
             :created_at,
             :updated_at
end
