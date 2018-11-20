Fabricator(:post_reply_key) do
  user
  post
  reply_key { PostReplyKey.generate_reply_key }
end
