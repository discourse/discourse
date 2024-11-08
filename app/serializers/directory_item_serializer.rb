# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer
  class UserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin

    attributes :user_fields

    def user_fields
      fields = {}
      user_custom_field_map = @options[:user_custom_field_map] || {}
      searchable_fields = @options[:searchable_fields] || []

      object.user_custom_fields.each do |custom_field|
        user_field_id = user_custom_field_map[custom_field.name]
        next unless user_field_id

        current_value = fields.dig(user_field_id, :value)

        current_value = Array(current_value) if current_value

        new_value = current_value ? current_value << custom_field.value : custom_field.value

        is_searchable = searchable_fields.any? { |field| field.id == user_field_id }

        fields[user_field_id] = {
          value: new_value.is_a?(Array) ? new_value : [new_value],
          searchable: is_searchable,
        }
      end

      fields
    end

    def include_user_fields?
      @options[:user_custom_field_map].present?
    end
  end

  has_one :user, embed: :objects, serializer: UserSerializer

  attributes :id

  def id
    object.user_id
  end

  private

  def attributes
    hash = super

    @options[:attributes].each { |attr| hash.merge!("#{attr}": object[attr]) }

    if object.period_type == DirectoryItem.period_types[:all]
      hash.merge!(time_read: object.user_stat.time_read)
    end

    hash
  end
end
