class EmailLogSerializer < ApplicationSerializer

  attributes :id,
             :reply_key,
             :to_address,
             :email_type,
             :user_id,
             :created_at,
             :skipped,
             :skipped_reason

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def filter(keys)
    keys.delete(:skipped_reason) unless object.skipped
    super(keys)
  end

end
