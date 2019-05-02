# frozen_string_literal: true

class CleanUpUserHistory < ActiveRecord::Migration[4.2]
  def up
    # 'checked_for_custom_avatar' is not used anymore
    # was removed in https://github.com/discourse/discourse/commit/6c1c8be79433f87bef9d768da7b8fa4ec9bb18d7
    UserHistory.where(action: UserHistory.actions[:checked_for_custom_avatar]).delete_all
  end

  def down
  end
end
