class QueuedPostSerializer < ApplicationSerializer
  attributes :id,
             :queue,
             :user_id,
             :state,
             :topic_id,
             :approved_by_id,
             :rejected_by_id,
             :raw,
             :post_options,
             :created_at

  has_one :user, serializer: BasicUserSerializer, embed: :object
end
