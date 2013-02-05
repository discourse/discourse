class AddSubTagToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :sub_tag, :string
    add_index :forum_threads, [:category_id, :sub_tag, :bumped_at]

    ForumThread.where("category_id is not null and title like '%:%'").each do |ft|
      if ft.title =~ /^(([a-zA-Z0-9]+)\: )(.*)/
        sub_tag = Regexp.last_match[2].downcase.strip
        execute "UPDATE forum_threads SET sub_tag = '#{sub_tag}' WHERE id = #{ft.id}"
      end
    end

  end
end
