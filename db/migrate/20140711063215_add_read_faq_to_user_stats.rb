class AddReadFaqToUserStats < ActiveRecord::Migration
  def change
    add_column :user_stats, :read_faq, :datetime
  end
end
