# frozen_string_literal: true

class AddOutboundMessageIdToPost < ActiveRecord::Migration[7.0]
  def change
    if !column_exists?(:posts, :outbound_message_id)
      add_column :posts, :outbound_message_id, :string
    end
  end
end
