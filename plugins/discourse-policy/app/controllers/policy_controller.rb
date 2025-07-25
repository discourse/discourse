# frozen_string_literal: true

class DiscoursePolicy::PolicyController < ::ApplicationController
  requires_plugin DiscoursePolicy::PLUGIN_NAME

  before_action :ensure_logged_in, :set_post
  before_action :ensure_can_accept, only: %i[accept unaccept]

  def accept
    PolicyUser.add!(current_user, @post.post_policy)
    @post.publish_change_to_clients!(:policy_change)

    if @post.post_policy.add_users_to_group.present?
      @post.post_policy.add_users_group.add(current_user)
    end

    render json: success_json
  end

  def unaccept
    PolicyUser.remove!(current_user, @post.post_policy)
    @post.publish_change_to_clients!(:policy_change)

    if @post.post_policy.add_users_to_group.present?
      @post.post_policy.add_users_group.remove(current_user)
    end

    render json: success_json
  end

  def accepted
    # Check if user has permission to see group members
    groups = @post.post_policy.groups
    return render_json_error(I18n.t("discourse_policy.errors.group_not_found")) if groups.blank?

    guardian = Guardian.new(current_user)
    unless guardian.can_see_groups_members?(groups)
      return render_json_error(I18n.t("discourse_policy.error.no_permission"))
    end

    users =
      @post
        .post_policy
        .accepted_by
        .offset(params[:offset])
        .limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)

    render json: { users: serialize_data(users, BasicUserSerializer) }
  end

  def not_accepted
    @post = Post.find(params[:post_id])

    # Check if user has permission to see group members
    groups = @post.post_policy.groups
    return render_json_error(I18n.t("discourse_policy.errors.group_not_found")) if groups.blank?

    guardian = Guardian.new(current_user)
    unless guardian.can_see_groups_members?(groups)
      return render_json_error(I18n.t("discourse_policy.error.no_permission"))
    end

    users =
      @post
        .post_policy
        .not_accepted_by
        .offset(params[:offset])
        .limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)

    render json: { users: serialize_data(users, BasicUserSerializer) }
  end

  private

  def ensure_can_accept
    if !GroupUser.where(
         "group_id in (:group_ids) and user_id = :user_id",
         group_ids: @group_ids,
         user_id: current_user.id,
       ).exists?
      return render_json_error(I18n.t("discourse_policy.errors.user_missing"))
    end

    true
  end

  def set_post
    raise Discourse::NotFound if !SiteSetting.policy_enabled

    params.require(:post_id)
    @post = Post.find_by(id: params[:post_id])

    raise Discourse::NotFound if !@post

    return render_json_error(I18n.t("discourse_policy.errors.no_policy")) if !@post.post_policy

    @group_ids = @post.post_policy.groups.pluck(:id)

    return render_json_error(I18n.t("discourse_policy.errors.group_not_found")) if @group_ids.blank?

    if SiteSetting.policy_restrict_to_staff_posts && !@post.user&.staff?
      return render_json_error(I18n.t("discourse_policy.errors.staff_only"))
    end

    true
  end
end
