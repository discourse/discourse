# frozen_string_literal: true

return if SiteSetting.directory_columns_seeded

[
  { name: "likes_received", position: 1, icon: "heart" },
  { name: "likes_given", position: 2, icon: "heart" },
  { name: "topic_count", position: 3, icon: nil },
  { name: "post_count", position: 4, icon: nil },
  { name: "topics_entered", position: 5, icon: nil },
  { name: "posts_read", position: 6, icon: nil },
  { name: "days_visited", position: 7, icon: nil },
].each do |column|
  DirectoryColumn.seed(:name) do |c|
    c.name = column[:name]
    c.automatic_position = column[:position]
    c.position = column[:position]
    c.icon = column[:icon]
    c.enabled = true
    c.type = DirectoryColumn.types[:automatic]
  end
end

SiteSetting.directory_columns_seeded = true
