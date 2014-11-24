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
    members = group.users.order('username_lower asc')
    members = members.limit(200) if group.automatic
    render_serialized(members.to_a, GroupUserSerializer)
  end

  # for PATCH requests
  def update
    guardian.ensure_can_edit!(the_group)

    added_users = []
    if actions = params[:changes]
      Array(actions[:add]).each do |username|
        if user = User.find_by_username(username)
          the_group.add(user)
          added_users << user
        end
      end
      Array(actions[:delete]).each do |username|
        if user = User.find_by_username(username)
          the_group.remove(user)
        end
      end
    end

    render_serialized(added_users, GroupUserSerializer)
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
