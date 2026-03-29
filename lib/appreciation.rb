# frozen_string_literal: true

class Appreciation
  include ActiveModel::Serialization

  attr_reader :type, :created_at, :post, :acting_user, :metadata

  def initialize(type:, created_at:, post:, acting_user:, metadata: {})
    @type = type
    @created_at = created_at
    @post = post
    @acting_user = acting_user
    @metadata = metadata
  end
end
