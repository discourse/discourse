# frozen_string_literal: true

class AddExcerptToTopicLocalization < ActiveRecord::Migration[7.2]
  def change
    add_column :topic_localizations, :excerpt, :string, null: true, default: nil
  end
end
