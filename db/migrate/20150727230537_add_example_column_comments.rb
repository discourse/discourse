# frozen_string_literal: true

require 'comment_migration'

class AddExampleColumnComments < CommentMigration

  def comments_up
    {
      posts: {
        _table: 'If you want to query public posts only, use the badge_posts view.',
        post_number: 'The position of this post in the topic. The pair (topic_id, post_number) forms a natural key on the posts table.',
        raw: 'The raw Markdown that the user entered into the composer.',
        cooked: 'The processed HTML that is presented in a topic.',
        reply_to_post_number: "If this post is a reply to another, this column is the post_number of the post it's replying to. [FKEY posts.topic_id, posts.post_number]",
        reply_quoted: 'This column is true if the post contains a quote-reply, which causes the in-reply-to indicator to be absent.',
      },
      topics: {
        _table: "To query public topics only: SELECT ... FROM topics t LEFT INNER JOIN categories c ON (t.category_id = c.id AND c.read_restricted = false)"
      },
    }
  end

  def comments_down
    {
    }
  end

end
