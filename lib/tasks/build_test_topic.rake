# Build a test topic full of links to test our replaceState/pushState functionality.

desc 'create pushstate/replacestate test topic'
task 'build_test_topic' => :environment do
  puts 'Creating topic'


  # Acceptable options:
  #
  #   raw                     - raw text of post
  #   image_sizes             - We can pass a list of the sizes of images in the post as a shortcut.
  #
  #   When replying to a topic:
  #     topic_id              - topic we're replying to
  #     reply_to_post_number  - post number we're replying to
  #
  #   When creating a topic:
  #     title                 - New topic title
  #     archetype             - Topic archetype
  #     category              - Category to assign to topic
  #     target_usernames      - comma delimited list of usernames for membership (private message)
  #     meta_data             - Topic meta data hash
  evil_trout = User.find_by_username('EvilTrout')

  first_post = PostCreator.new(evil_trout, raw: "This is the original post.", title: "pushState/replaceState test topic").create
  topic = first_post.topic

  topic_url = "#{Discourse.base_url}/t/#{Slug.for(topic.title)}/#{topic.id}"

  99.times do |i|
    post_number = (i + 2)

    links = []
    [-30, -10, 10, 30].each do |offset|
      where = (post_number + offset)
      if where >= 1 and where <= 100
        links << "Link to ##{where}: #{topic_url}/#{where}"
      end
    end

    raw = <<eos
This is post ##{post_number}.

#{links.join("\n")}
eos

    PostCreator.new(evil_trout, raw: raw, topic_id: topic.id).create
  end

end
