# frozen_string_literal: true

class GroupMentionsUpdater
  def self.update(current_name, previous_name)
    rewrite = ->(text) do
      text.gsub(/(^|\s)(@#{Regexp.escape(previous_name)})(?=\s|$)/, "\\1@#{current_name}")
    end
    Post
      .where(
        "cooked LIKE '%class=\"mention-group%' AND raw LIKE :previous_name",
        previous_name: "%@#{previous_name}%",
      )
      .or(Post.where("form_data::text LIKE ?", "%@#{Post.sanitize_sql_like(previous_name)}%"))
      .find_in_batches do |posts|
        posts.each do |post|
          post.with_lock do
            post.assign_attributes(post.rewritten_content(&rewrite))
            post.save!(validate: false) if post.changed?
          end
          post.sync_first_post_caches
        end
      end
  end
end
