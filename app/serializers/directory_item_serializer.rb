# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin

    attributes :user_fields

    def user_fields
      fields = {}

      object.user_custom_fields.each do |cuf|
        user_field_id = @options[:user_custom_field_map][cuf.name]
        if user_field_id
          fields[user_field_id] = cuf.value
        end
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

    @options[:attributes].each do |attr|
      hash.merge!("#{attr}": object[attr])
    end

    if object.period_type == DirectoryItem.period_types[:all]
      hash.merge!(time_read: object.user_stat.time_read)
    end

    hash
  end
end
