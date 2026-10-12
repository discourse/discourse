# frozen_string_literal: true

class PostUpdateSerializer < PostSerializer
  def initialize(post, options)
    guardian = options[:scope]
    user = options[:user] || guardian.user
    link_counts = TopicLink.counts_for(guardian, post.topic, [post])

    super(
      post,
      options.merge(
        add_raw: true,
        draft_sequence: DraftSequence.current(user, post.topic.draft_key),
        single_post_link_counts: link_counts[post.id],
      ),
    )
  end
end
