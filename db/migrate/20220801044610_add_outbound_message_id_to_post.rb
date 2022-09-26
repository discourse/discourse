# frozen_string_literal: true

class AddOutboundMessageIdToPost < ActiveRecord::Migration[7.0]
  def change
    add_column :posts, :outbound_message_id, :string
  end
end
