# frozen_string_literal: true
class WebHookLikeSerializer < ApplicationSerializer
  attributes :post,
             :user
  def post
    WebHookPostSerializer.new(object.post, scope: scope, root: false).as_json
  end
  def user
    BasicUserSerializer.new(object.user, scope: scope, root: false).as_json
  end
end
