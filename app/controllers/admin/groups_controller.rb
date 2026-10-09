# frozen_string_literal: true

class Admin::GroupsController < Admin::StaffController
  MAX_AUTO_MEMBERSHIP_DOMAINS_LOOKUP = 10

  def index
  end

  def create
    Groups::Create.call(
      guardian:,
      params: group_params.except(*DiscoursePluginRegistry.group_params),
      options: {
        dynamic_attributes: group_params.slice(*DiscoursePluginRegistry.group_params),
      },
    ) do |result|
      on_success { |group:| render_serialized(group.reload, BasicGroupSerializer) }
      on_failed_policy(:can_create_group) { |policy| raise Discourse::InvalidAccess }
      on_failed_policy(:can_request_access) do
        render json:
                 failed_json.merge(
                   errors: [I18n.t("groups.errors.cant_allow_membership_requests")],
                 ),
               status: :unprocessable_entity
      end
      on_model_errors(:group) { |group:| render_json_error(group) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
    end
  end

  def destroy
    group = Group.find_by(id: params[:id])
    raise Discourse::NotFound unless group

    GroupDestroyer.destroy(guardian, group)

    render json: success_json
  rescue GroupMutations::AutomaticGroup => error
    render_json_error(error.message)
  end

  def remove_owner
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    user_id = params[:user_id]
    GroupOwnerManager.remove(
      guardian,
      group,
      user_id:,
      usernames: user_id.present? ? nil : group_params[:usernames],
    )

    render json: success_json
  rescue GroupMutations::AutomaticGroup => error
    render_json_error(error.message)
  end

  def set_primary
    group = Group.find_by(id: params.require(:id))
    raise Discourse::NotFound unless group

    users = User.where(username: group_params[:usernames].split(","))
    users.each { |user| guardian.ensure_can_change_primary_group!(user, group) }
    users.update_all(primary_group_id: params[:primary] == "true" ? group.id : nil)

    render json: success_json
  end

  def automatic_membership_count
    guardian.ensure_can_create_group!
    domains = Group.get_valid_email_domains(params.require(:automatic_membership_email_domains))
    group_id = params[:id]
    user_count = 0

    if domains.present?
      if group_id.present?
        group = Group.find_by(id: group_id)
        raise Discourse::NotFound unless group

        return can_not_modify_automatic if group.automatic

        existing_domains = group.automatic_membership_email_domains&.split("|") || []
        domains -= existing_domains
      end

      if domains.size > MAX_AUTO_MEMBERSHIP_DOMAINS_LOOKUP
        user_count = nil
      else
        user_count = Group.automatic_membership_users(domains.join("|")).count
      end
    end

    render json: { user_count: }
  end

  protected

  def can_not_modify_automatic
    render_json_error(I18n.t("groups.errors.can_not_modify_automatic"))
  end

  private

  def group_params
    permitted = %i[
      name
      mentionable_level
      messageable_level
      visibility_level
      members_visibility_level
      automatic_membership_email_domains
      title
      primary_group
      grant_trust_level
      incoming_email
      flair_icon
      flair_upload_id
      flair_bg_color
      flair_color
      bio_raw
      public_admission
      public_exit
      allow_membership_requests
      full_name
      default_notification_level
      membership_request_template
      owner_usernames
      usernames
      publish_read_state
      notify_users
    ]
    custom_fields = DiscoursePluginRegistry.editable_group_custom_fields
    permitted << { custom_fields: custom_fields } if custom_fields.present?

    permitted << { associated_group_ids: [] } if guardian.can_associate_groups?

    permitted = permitted | DiscoursePluginRegistry.group_params

    params.require(:group).permit(permitted)
  end
end
