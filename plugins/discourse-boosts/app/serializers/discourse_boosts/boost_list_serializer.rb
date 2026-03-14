# frozen_string_literal: true

module DiscourseBoosts
  class BoostListSerializer < ::ApplicationSerializer
    attributes :id, :raw, :cooked, :created_at, :post_id

    has_one :user, serializer: ::BasicUserSerializer, embed: :objects
    has_one :post, serializer: BoostListPostSerializer, embed: :objects
  end
end
