# The most basic attributes of a topic that we need to create a link for it.
class PostWordpressSerializer < BasicPostSerializer

  include UrlHelper

  def avatar_template
    if object.user
      absolute object.user.avatar_template
    else
      nil
    end
  end

end
