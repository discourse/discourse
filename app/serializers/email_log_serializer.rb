class EmailLogSerializer < ApplicationSerializer
  include EmailLogsMixin

  attributes :reply_key,
             :bounced

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def include_reply_key?
    reply_keys = @options[:reply_keys]
    reply_keys.present? && reply_keys[[object.post_id, object.user_id]]
  end

  def reply_key
    @options[:reply_keys][[object.post_id, object.user_id]].delete("-")
  end
end
