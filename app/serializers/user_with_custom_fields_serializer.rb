# frozen_string_literal: true

# A basic user serializer, with custom fields
class UserWithCustomFieldsSerializer < BasicUserSerializer
  attributes :custom_fields, :status

  def custom_fields
    fields = custom_field_keys

    if fields.present?
      if object.custom_fields_preloaded?
        {}.tap { |h| fields.each { |f| h[f] = object.custom_fields[f] } }
      else
        User.custom_fields_for_ids([object.id], fields)[object.id] || {}
      end
    else
      {}
    end
  end

  def include_status?
    predicate = @options[:include_status] && SiteSetting.enable_user_status && user.has_status?

    if user.association(:user_option).loaded?
      predicate = predicate && !user.user_option.hide_profile_and_presence
    end

    predicate
  end

  def status
    ::UserStatusSerializer.new(user.user_status, root: false)
  end

  private

  def custom_field_keys
    # Can be extended by other serializers
    User.allowed_user_custom_fields(scope)
  end
end
