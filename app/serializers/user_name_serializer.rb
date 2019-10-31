# frozen_string_literal: true

class UserNameSerializer < BasicUserSerializer
  root 'user_name'
  attributes :name, :title
end
