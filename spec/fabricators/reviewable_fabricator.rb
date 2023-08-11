# frozen_string_literal: true

Fabricator(:reviewable) do
  reviewable_by_moderator true
  type "ReviewableUser"
  created_by { Fabricate(:user) }
  target_id { Fabricate(:user).id }
  target_type "User"
  target_created_by { Fabricate(:user) }
  category
  score 1.23
  payload { { list: [1, 2, 3], name: "bandersnatch" } }
end

Fabricator(:reviewable_queued_post_topic, class_name: :reviewable_queued_post) do
  reviewable_by_moderator true
  type "ReviewableQueuedPost"
  created_by { Fabricate(:user) }
  target_created_by { Fabricate(:user) }
  category
  payload do
    {
      raw: "hello world post contents.",
      title: "queued post title",
      tags: %w[cool neat],
      extra: "some extra data",
      archetype: "regular",
    }
  end
end

Fabricator(:reviewable_queued_post) do
  reviewable_by_moderator true
  type "ReviewableQueuedPost"
  created_by { Fabricate(:user) }
  target_created_by { Fabricate(:user) }
  topic
  payload do
    {
      raw: "hello world post contents.",
      reply_to_post_number: 1,
      via_email: true,
      raw_email: "store_me",
      auto_track: true,
      custom_fields: {
        hello: "world",
      },
      cooking_options: {
        cat: "hat",
      },
      cook_method: Post.cook_methods[:raw_html],
      image_sizes: {
        "http://foo.bar/image.png" => {
          "width" => 0,
          "height" => 222,
        },
      },
    }
  end
end

Fabricator(:reviewable_queued_long_post, from: :reviewable_queued_post) do
  reviewable_by_moderator true
  type "ReviewableQueuedPost"
  created_by { Fabricate(:user) }
  target_created_by { Fabricate(:user) }
  topic
  payload do
    {
      raw:
        "This is a sample post with very long raw content. The raw content is actually so long
      that there is no way it could be longer. It is adding so many characters to the post content
      so that we can use it in testing for scenarios where a post is very long and might cause issues.
      The post is so long in fact, that the text is split into various paragraphs. Some people are not
      very concise in their words. They tend to ramble and ramble on about certain information. This
      is why we need to make sure that we are going about testing in certain ways so that when people
      such as those that ramble on, are making posts, we can be sure that the posts are not causing
      any issues. When issues happen it can cause lots of problems. For example, if a post is too long,
      it affects the way it can be viewed by others.
      Depending on the screen size, it may cause a lot of scrolling to take place. This is not good.
      In certain cases, we want to truncate the content of the post when its too long so that it does
      not cause issues. This is why we need to make sure that we are testing for these scenarios. I think
      this post has gotten very long, however, I would like to make sure that it is a bit longer, so I
      will add one final sentence. This is my final sentence, thank you for reading, goodbye.",
      reply_to_post_number: 1,
      via_email: true,
      raw_email: "store_me",
      auto_track: true,
      custom_fields: {
        hello: "world",
      },
      cooking_options: {
        cat: "hat",
      },
      cook_method: Post.cook_methods[:raw_html],
      image_sizes: {
        "http://foo.bar/image.png" => {
          "width" => 0,
          "height" => 222,
        },
      },
    }
  end
end

Fabricator(:reviewable_flagged_post) do
  reviewable_by_moderator true
  type "ReviewableFlaggedPost"
  created_by { Fabricate(:user) }
  topic
  target_type "Post"
  target { Fabricate(:post) }
  reviewable_scores { |p| [Fabricate.build(:reviewable_score, reviewable_id: p[:id])] }
end

Fabricator(:reviewable_user) do
  reviewable_by_moderator true
  type "ReviewableUser"
  created_by { Fabricate(:user) }
  target_type "User"
  target { Fabricate(:user) }
end
