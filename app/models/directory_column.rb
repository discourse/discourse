# frozen_string_literal: true

class DirectoryColumn < ActiveRecord::Base

  # TODO(2021-06-18): Remove automatic column
  self.ignored_columns = ["automatic"]
  self.inheritance_column = nil

  enum type: { automatic: 0, user_field: 1, plugin: 2 }, _scopes: false

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

  def self.plugin_directory_columns
    @@plugin_directory_columns
  end

  belongs_to :user_field

  def self.clear_plugin_directory_columns
    @@plugin_directory_columns = []
  end

  def self.find_or_create_plugin_directory_column(attrs)
    directory_column = find_or_create_by(
      name: attrs[:column_name],
      icon: attrs[:icon],
      type: DirectoryColumn.types[:plugin]
    ) do |column|
      column.position = DirectoryColumn.maximum("position") + 1
      column.enabled = false
    end

    unless @@plugin_directory_columns.include?(directory_column.name)
      @@plugin_directory_columns << directory_column.name
      DirectoryItem.add_plugin_query(attrs[:query])
    end
  end
end

# == Schema Information
#
# Table name: directory_columns
#
#  id                 :bigint           not null, primary key
#  name               :string
#  automatic_position :integer
#  icon               :string
#  user_field_id      :integer
#  enabled            :boolean          not null
#  position           :integer          not null
#  created_at         :datetime
#  type               :integer          default("automatic"), not null
#
# Indexes
#
#  directory_column_index  (enabled,position,user_field_id)
#
