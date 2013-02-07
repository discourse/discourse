class CategoryFeaturedUsersSerializer < CategorySerializer

  has_many :featured_users, serializer: BasicUserSerializer, embed: :objects

end
