# frozen_string_literal: true

class DirectoryColumn < ActiveRecord::Base
  self.inheritance_column = nil

  def self.automatic_column_names
    @automatic_column_names ||= [:likes_received,
                   :likes_given,
                   :topics_entered,
                   :topic_count,
                   :post_count,
                   :posts_read,
                   :days_visited]
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
end
