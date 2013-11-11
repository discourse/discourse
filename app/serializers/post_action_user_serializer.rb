class PostActionUserSerializer < BasicUserSerializer
  attributes :post_url

  # reserved
  def post_url
    object.post_url
  end
end
