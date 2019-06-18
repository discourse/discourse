# frozen_string_literal: true

# The most basic attributes of a topic that we need to create a link for it.
class PostWordpressSerializer < BasicPostSerializer
  attributes :post_number

  def avatar_template
    if object.user
      UrlHelper.absolute object.user.avatar_template
    else
      nil
    end
  end

end
