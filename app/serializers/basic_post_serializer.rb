# frozen_string_literal: true

# The most basic attributes of a topic that we need to create a link for it.
class BasicPostSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :username,
             :avatar_template,
             :created_at,
             :cooked,
             :cooked_hidden

  def name
    object.user && object.user.name
  end

  def username
    object.user && object.user.username
  end

  def avatar_template
    object.user && object.user.avatar_template
  end

  def cooked_hidden
    object.hidden && !scope.is_staff?
  end

  def include_cooked_hidden?
    cooked_hidden
  end

  def cooked
    if cooked_hidden
      if scope.current_user && object.user_id == scope.current_user.id
        I18n.t('flagging.you_must_edit', path: "/my/messages")
      else
        I18n.t('flagging.user_must_edit')
      end
    else
      cooked = object.filter_quotes(@parent_post)

      if scope&.user
        group = Group
          .joins('JOIN group_users ON groups.id = group_users.group_id')
          .find_by(
            id: object.custom_fields['requested_group_id'].to_i,
            group_users: { user_id: scope.user.id, owner: true }
          )

        if group
          cooked << <<~EOF
            <hr />
            <a href="#{Discourse.base_uri}/g/#{group.name}/requests">
              #{I18n.t('groups.request_membership_pm.handle')}
            </a>
          EOF
        end
      end

      cooked
    end
  end

  def include_name?
    SiteSetting.enable_names?
  end

end
