# frozen_string_literal: true

class DirectoryColumn < ActiveRecord::Base
  self.inheritance_column = nil

  # TODO(2021-06-18): Remove
  self.ignored_columns = ["automatic"]

  def self.automatic_column_names
    @automatic_column_names ||= [:likes_received,
                   :likes_given,
                   :topics_entered,
                   :topic_count,
                   :post_count,
                   :posts_read,
                   :days_visited]
  end

  def self.active_column_names
    DirectoryColumn.where(type: [:automatic, :plugin]).where(enabled: true).pluck(:name).map(&:to_sym)
  end

  @@plugin_directory_columns = []

  enum type: { automatic: 0, user_field: 1, plugin: 2 }

  belongs_to :user_field

  def self.add_plugin_directory_column(name)
    @@plugin_directory_columns << name
  end

  def self.plugin_directory_columns
    @@plugin_directory_columns
  end

  def self.clear_plugin_directory_columns
    @@plugin_directory_columns = []
  end

  def self.create_plugin_directory_column(attrs)
    directory_column = find_or_create_by(
      name: attrs[:column_name],
      icon: attrs[:icon],
      type: DirectoryColumn.types[:plugin]
    ) do |column|
      column.position = DirectoryColumn.maximum("position") + 1
      column.enabled = false
    end

    raise "Error creating plugin directory column '#{attrs[:column_name]}'" unless directory_column&.id

    add_plugin_directory_column(directory_column.name)
    DirectoryItem.add_plugin_query(attrs[:query])
  end
end
