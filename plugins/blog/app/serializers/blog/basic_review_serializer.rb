# frozen_string_literal: true

module ::Blog
  class BasicReviewSerializer < ApplicationSerializer
    attributes :id, :label, :post_version, :revoked_at
  end
end
