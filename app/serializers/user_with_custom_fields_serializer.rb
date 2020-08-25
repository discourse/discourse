# frozen_string_literal: true

# A basic user serializer, with custom fields
class UserWithCustomFieldsSerializer < BasicUserSerializer
  attributes :custom_fields

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

  private

  def custom_field_keys
    # Can be extended by other serializers
    User.allowed_user_custom_fields(scope)
  end
end
