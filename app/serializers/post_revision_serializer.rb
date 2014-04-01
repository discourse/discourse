class PostRevisionSerializer < ApplicationSerializer
  attributes :post_id,
             :version,
             :revisions_count,
             :username,
             :display_username,
             :avatar_template,
             :created_at,
             :edit_reason,
             :body_changes,
             :title_changes,
             :category_changes

  def include_title_changes?
    object.has_topic_data?
  end

  def include_category_changes?
    object.has_topic_data?
  end

  def version
    object.number
  end

  def revisions_count
    object.post.version
  end

  def username
    user.username_lower
  end

  def display_username
    user.username
  end

  def avatar_template
    user.avatar_template
  end

  def edit_reason
    object.lookup("edit_reason", 1)
  end

  def user
    # if stuff goes pear shape attribute to system
    object.user || Discourse.system_user
  end

end
