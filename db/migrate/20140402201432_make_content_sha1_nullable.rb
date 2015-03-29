class MakeContentSha1Nullable < ActiveRecord::Migration
  def change
    change_column :topic_embeds, :content_sha1, :string, :limit => 40, :null => true
  end
end
