# frozen_string_literal: true

module NestedRepliesHelpers
  def create_reply_chain(depth:, parent: op)
    posts = [parent]
    depth.times do |i|
      reply_to = i == 0 && parent == op ? nil : posts.last.post_number
      posts << Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        raw: "Reply at depth #{i + 1}",
        reply_to_post_number: reply_to || posts.last.post_number,
      )
    end
    posts[1..]
  end
end
