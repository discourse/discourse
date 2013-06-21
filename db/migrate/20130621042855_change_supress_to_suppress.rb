class ChangeSupressToSuppress < ActiveRecord::Migration
  def up
    SiteSetting.update_all({name: "supress_reply_directly_below"}, name: "suppress_reply_directly_below")
  end

  def down
    SiteSetting.update_all({name: "suppress_reply_directly_below"}, name: "supress_reply_directly_below")
  end
end
