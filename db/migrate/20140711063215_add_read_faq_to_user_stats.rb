# frozen_string_literal: true

class AddReadFaqToUserStats < ActiveRecord::Migration[4.2]
  def change
    add_column :user_stats, :read_faq, :datetime
  end
end
