# frozen_string_literal: true

class AddMobileToUserVisits < ActiveRecord::Migration[4.2]
  def change
    add_column :user_visits, :mobile, :boolean, default: false
  end
end
