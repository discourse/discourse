# frozen_string_literal: true
class ReactionSerializer < ApplicationSerializer
  attributes :id, :post_id, :reaction_type, :reaction_value, :reaction_users_count, :created_at
end
