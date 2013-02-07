require_dependency 'excerpt_type'

class UserExcerptSerializer < ActiveModel::Serializer
  include ExcerptType

  # TODO: Inherit from basic user serializer?

  attributes :bio_cooked, :username, :url, :name, :avatar_template

  def url
    user_path(object.username.downcase)
  end

end
