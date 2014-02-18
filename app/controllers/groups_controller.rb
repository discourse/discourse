class GroupsController < ApplicationController

  def show
    group = Group.where(name: params.require(:id)).first
    guardian.ensure_can_see!(group)
    render_serialized(group, BasicGroupSerializer)
  end

  def counts
    group = Group.where(name: params.require(:group_id)).first
    guardian.ensure_can_see!(group)
    render json: {counts: { posts: group.posts_for(guardian).count,
                            members: group.users.count } }
  end

  def posts
    group = Group.where(name: params.require(:group_id)).first
    guardian.ensure_can_see!(group)
    posts = group.posts_for(guardian, params[:before_post_id]).limit(20)
    render_serialized posts.to_a, GroupPostSerializer
  end

  def members
    group = Group.where(name: params.require(:group_id)).first
    guardian.ensure_can_see!(group)
    render_serialized(group.users.order('username_lower asc').limit(200).to_a, GroupUserSerializer)
  end

end
