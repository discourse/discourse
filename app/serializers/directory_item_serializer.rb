# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin

    attributes :user_fields

    def user_fields
      object.user_fields(@options[:user_field_ids])
    end

    def include_user_fields?
      user_fields.present?
    end
  end

  attributes :id,
             :time_read,
             # :plugin_attrs

  has_one :user, embed: :objects, serializer: UserSerializer
  attributes *DirectoryColumn.automatic_column_names

  def id
    object.user_id
  end

  def time_read
    object.user_stat.time_read
  end

  def include_time_read?
    object.period_type == DirectoryItem.period_types[:all]
  end

  # def plugin_attrs
    # attrs = {}
    # @options[:plugin_column_ids].map do |column_id|
      # directory_column = DirectoryColumn.plugin_directory_columns.detect { |column| column[:id] == column_id }
      # attrs[column_id] = directory_column[:value_proc].call(object)
    # end
    # attrs
  # end

  # def include_plugin_attrs?
    # @options[:plugin_column_ids]
  # end
end
