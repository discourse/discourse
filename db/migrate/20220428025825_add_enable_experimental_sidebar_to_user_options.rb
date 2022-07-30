# frozen_string_literal: true

class AddEnableExperimentalSidebarToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :enable_experimental_sidebar, :boolean, default: false
  end
end
