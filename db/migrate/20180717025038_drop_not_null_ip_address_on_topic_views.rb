class DropNotNullIpAddressOnTopicViews < ActiveRecord::Migration[5.2]
  def change
    begin
      Migration::SafeMigrate.disable!
      change_column_null :topic_views, :ip_address, true
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end
