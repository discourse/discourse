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

    limit = (params[:limit] || 50).to_i
    offset = params[:offset].to_i

    total = group.users.count
    members = group.users.order(:username_lower).limit(limit).offset(offset)

    render json: {
      members: serialize_data(members, GroupUserSerializer),
      meta: {
        total: total,
        limit: limit,
        offset: offset
      }
    }
  end

  def add_members
    guardian.ensure_can_edit!(the_group)

    added_users = []
    usernames = params.require(:usernames)
    usernames.split(",").each do |username|
      if user = User.find_by_username(username)
        unless the_group.users.include?(user)
          the_group.add(user)
          added_users << user
        end
      end
    end

    # always succeeds, even if bogus usernames were provided
    render_serialized(added_users, GroupUserSerializer)
  end

  def remove_member
    guardian.ensure_can_edit!(the_group)

    removed_users = []
    username = params.require(:username)
    if user = User.find_by_username(username)
      the_group.remove(user)
      removed_users << user
    end

    # always succeeds, even if user was not a member
    render_serialized(removed_users, GroupUserSerializer)
  end

  private

    def find_group(param_name)
      name = params.require(param_name)
      group = Group.find_by("lower(name) = ?", name.downcase)
      guardian.ensure_can_see!(group)
      group
    end

    def the_group
      @the_group ||= find_group(:group_id)
    end

end
