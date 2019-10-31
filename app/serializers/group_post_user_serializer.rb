# frozen_string_literal: true

class GroupPostUserSerializer < BasicUserSerializer
  root 'group_post_user'

  attributes :title, :name
end
