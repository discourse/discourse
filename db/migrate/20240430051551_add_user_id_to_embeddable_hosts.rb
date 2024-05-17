# frozen_string_literal: true
class AddUserIdToEmbeddableHosts < ActiveRecord::Migration[7.0]
  def change
    add_column :embeddable_hosts, :user_id, :integer
  end
end
