class ChangeSupressToSuppress < ActiveRecord::Migration
  def up
    SiteSetting.where(name: "suppress_reply_directly_below").update_all({name: "supress_reply_directly_below"})
  end

  def down
    SiteSetting.where(name: "supress_reply_directly_below").update_all({name: "suppress_reply_directly_below"})
  end
end
