# frozen_string_literal: true
class RenameChatPreferredMobileIndex < ActiveRecord::Migration[7.1]
  def change
    SiteSetting.transaction do
      setting = SiteSetting.find_by(name: "chat_preferred_mobile_index")
      setting.update!(name: "chat_preferred_index") if setting
    end
  end

  def down
    SiteSetting.transaction do
      setting = SiteSetting.find_by(name: "chat_preferred_index")
      setting.update!(name: "chat_preferred_mobile_index") if setting
    end
  end
end
