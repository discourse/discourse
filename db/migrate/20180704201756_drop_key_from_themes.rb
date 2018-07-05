class DropKeyFromThemes < ActiveRecord::Migration[5.2]
  def up
    begin
      Migration::SafeMigrate.disable!
      remove_column :themes, :key
    ensure
      Migration::SafeMigrate.enable!
    end
  end

  def down
    add_column :themes, :key, :string, null: false, default: ""
    execute("UPDATE themes AS t SET key = (SELECT uuid_in(md5((t.id)::text || (t.name)::text)::cstring))")
  end
end
