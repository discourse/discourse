class GroupsController < ApplicationController

  def show
    render_serialized(find_group(:id), BasicGroupSerializer)
  end

  def counts
    group = find_group(:group_id)
    render json: {counts: { posts: group.posts_for(guardian).count,
                            members: group.users.count } }
  end

  def posts
    group = find_group(:group_id)
    posts = group.posts_for(guardian, params[:before_post_id]).limit(20)
    render_serialized posts.to_a, GroupPostSerializer
  end

  def members
    group = find_group(:group_id)

    limit = (params[:limit] || 200).to_i
    offset = (params[:offset] || 0).to_i

    paginated_members = group.users.order('username_lower asc').limit(limit).offset(offset)

    render_serialized(paginated_members.to_a, GroupUserSerializer)
  end

  def update
    logger.info("HERE WE ARE IN GROUP UPDATE WITH #{params}")
    guardian.ensure_can_edit!(the_group)
    logger.info("GROUP EDIT IS OK FOR #{the_group.name}")

    if actions = params[:changes]
      if actions[:add] && usernames = Array(actions[:add])
        users = User.where(username: usernames)
        # the_group.add(users)
        render_serialized(users, GroupUserSerializer)
      elsif actions[:delete] && usernames = Array(actions[:delete])
        users = User.where(username: usernames)
        # the_group.remove(users)
        render nothing: true
      else
        render nothing: true
      end
    end
  end

  private

  def find_group(param_name)
    name = params.require(param_name)
    group = Group.find_by("lower(name) = ?", name.downcase)
    guardian.ensure_can_see!(group)
    group
  end

  def the_group
    @the_group ||= find_group(:id)
  end
end
