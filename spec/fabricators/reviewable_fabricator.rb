# frozen_string_literal: true

Fabricator(:reviewable) do
  reviewable_by_moderator true
  type 'ReviewableUser'
  created_by { Fabricate(:user) }
  target_id { Fabricate(:user).id }
  target_type "User"
  target_created_by { Fabricate(:user) }
  category
  score 1.23
  payload {
    { list: [1, 2, 3], name: 'bandersnatch' }
  }
end

Fabricator(:reviewable_queued_post_topic, class_name: :reviewable_queued_post) do
  reviewable_by_moderator true
  type 'ReviewableQueuedPost'
  created_by { Fabricate(:user) }
  category
  payload {
    {
      raw: "hello world post contents.",
      title: "queued post title",
      tags: ['cool', 'neat'],
      extra: "some extra data",
      archetype: 'regular'
    }
  }
end

Fabricator(:reviewable_queued_post) do
  reviewable_by_moderator true
  type 'ReviewableQueuedPost'
  created_by { Fabricate(:user) }
  topic
  payload {
    {
      raw: "hello world post contents.",
      reply_to_post_number: 1,
      via_email: true,
      raw_email: 'store_me',
      auto_track: true,
      custom_fields: { hello: 'world' },
      cooking_options: { cat: 'hat' },
      cook_method: Post.cook_methods[:raw_html],
      image_sizes: { "http://foo.bar/image.png" => { "width" => 0, "height" => 222 } }
    }
  }
end

Fabricator(:reviewable_flagged_post) do
  reviewable_by_moderator true
  type 'ReviewableFlaggedPost'
  created_by { Fabricate(:user) }
  topic
  target_type 'Post'
  target { Fabricate(:post) }
end

Fabricator(:reviewable_user) do
  reviewable_by_moderator true
  type 'ReviewableUser'
  created_by { Fabricate(:user) }
  target_type 'User'
  target { Fabricate(:user) }
end
