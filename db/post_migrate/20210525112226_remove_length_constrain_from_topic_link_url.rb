# frozen_string_literal: true

class RemoveLengthConstrainFromTopicLinkUrl < ActiveRecord::Migration[6.1]
  def up
    change_column :topic_links, :url, :string, null: false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
