Fabricator(:post) do
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
  raw "Hello world"
end

Fabricator(:post_with_youtube, from: :post) do
  cooked '<p><a href="http://www.youtube.com/watch?v=9bZkp7q19f0" class="onebox" target="_blank">http://www.youtube.com/watch?v=9bZkp7q19f0</a></p>'
end

Fabricator(:old_post, from: :post) do
  topic {|attrs| Fabricate(:topic, user: attrs[:user], created_at: (DateTime.now - 100) ) }
  created_at (DateTime.now - 100)
end

Fabricator(:moderator_post, from: :post) do
  user
  topic {|attrs| Fabricate(:topic, user: attrs[:user] ) }
  post_type Post.types[:moderator_action]
  raw "Hello world"
end

Fabricator(:basic_reply, from: :post) do
  user(:coding_horror)
  reply_to_post_number 1
  topic
  raw 'this reply has no quotes'
end

Fabricator(:reply, from: :post) do
  user(:coding_horror)
  topic
  raw '
    [quote="Evil Trout, post:1"]hello[/quote]
    Hmmm!
  '
end

Fabricator(:post_with_images_in_quote_and_onebox, from: :post) do
  cooked '
<aside class="quote"><img src="/uploads/default/1/1234567890123456.jpg"></aside>
<div class="onebox-result"><img src="/uploads/default/1/1234567890123456.jpg"></div>
'
end

Fabricator(:post_with_uploaded_image, from: :post) do
  cooked '<img src="/uploads/default/2/3456789012345678.png" width="1500" height="2000">'
end

Fabricator(:post_with_an_attachment, from: :post) do
  cooked '<a class="attachment" href="/uploads/default/186/66b3ed1503efc936.zip">archive.zip</a>'
end

Fabricator(:post_with_unsized_images, from: :post) do
  cooked '
<img src="http://foo.bar/image.png">
<img src="/uploads/default/1/1234567890123456.jpg">
'
end

Fabricator(:post_with_image_url, from: :post) do
  cooked '<img src="http://foo.bar/image.png" width="50" height="42">'
end

Fabricator(:post_with_large_image, from: :post) do
  cooked '<img src="/uploads/default/1/1234567890123456.jpg">'
end

Fabricator(:post_with_uploads, from: :post) do
  cooked '
<a href="/uploads/default/2/2345678901234567.jpg">Link</a>
<img src="/uploads/default/1/1234567890123456.jpg">
'
end

Fabricator(:post_with_uploads_and_links, from: :post) do
  cooked '
<a href="/uploads/default/2/2345678901234567.jpg">Link</a>
<img src="/uploads/default/1/1234567890123456.jpg">
<a href="http://www.google.com">Google</a>
<img src="http://foo.bar/image.png">
'
end

Fabricator(:post_with_external_links, from: :post) do
  user
  topic
  raw "
Here's a link to twitter: http://twitter.com
And a link to google: http://google.com
And a markdown link: [forumwarz](http://forumwarz.com)
And a markdown link with a period after it [codinghorror](http://www.codinghorror.com/blog).
  "
end

Fabricator(:private_message_post, from: :post) do
  user
  topic do |attrs|
    Fabricate( :private_message_topic,
      user: attrs[:user],
      created_at: attrs[:created_at],
      subtype: TopicSubtype.user_to_user,
      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user_id: attrs[:user].id),
        Fabricate.build(:topic_allowed_user, user_id: Fabricate(:user).id)
      ]
    )
  end
  raw "Ssshh! This is our secret conversation!"
end
