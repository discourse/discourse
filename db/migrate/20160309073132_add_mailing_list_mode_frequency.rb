# frozen_string_literal: true

class AddMailingListModeFrequency < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :mailing_list_mode_frequency, :integer, default: 0, null: false
  end
end
