# frozen_string_literal: true

class AddDomainToInvites < ActiveRecord::Migration[6.1]
  def change
    add_column :invites, :domain, :string
  end
end
