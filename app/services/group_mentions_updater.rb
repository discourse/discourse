# frozen_string_literal: true

class GroupMentionsUpdater
  def self.update(current_name, previous_name)
    Post.where(
      "cooked LIKE '%class=\"mention-group\"%' AND raw LIKE :previous_name",
      previous_name: "%@#{previous_name}%"
    ).find_in_batches do |posts|

      posts.each do |post|
        post.raw.gsub!(/(^|\s)(@#{previous_name})(\s|$)/, "\\1@#{current_name}\\3")
        post.save!(validate: false)
      end
    end
  end
end
