# frozen_string_literal: true

class AllowNullIpTopicLinkClick < ActiveRecord::Migration[5.1]
  def up
    begin
      Migration::SafeMigrate.disable!
      change_column :topic_link_clicks, :ip_address, :inet, null: true
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end
