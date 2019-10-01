# frozen_string_literal: true

# Generates posts and topics
class Populate < Thor
  desc "posts", "Generate posts"
  long_desc <<-LONGDESC
    Create topics with any number of posts, or add posts to an existing topic.

    Examples:

    Create a new topic with 100 posts from batman and spiderman:

    > $ thor populate:posts -n 100 -u batman spiderman -t "So many posts"

    Add 10 posts to topic with id 123:

    > $ thor populate:posts -n 10 -u batman spiderman -i 123

    Generate 10 topics with 5 posts:

    > $ thor populate:posts -p 10 -n 5

  LONGDESC
  method_option :num_posts, aliases: '-n',  type: :numeric, required: true, desc: "Number of posts to make"
  method_option :users,     aliases: '-u',  type: :array, desc: "Usernames of users who will make the posts"
  method_option :title,     aliases: '-t',  desc: "The title of the topic, if making a new topic"
  method_option :topic_id,  aliases: '-i', type: :numeric, desc: "The id of the topic where the posts will be added"
  method_option :num_topics, aliases: '-p', type: :numeric, default: 1, desc: "Number of topics to create"

  def posts
    require './config/environment'
    users = []
    if options[:users]
      options[:users].each do |u|
        provided_user = User.find_by_username(u.downcase)
        puts "No user found: #{provided_user}" if provided_user.nil?
        users << provided_user if provided_user
      end
    else
      10.times do
        user = create_user(generate_email)
        users << user
      end
    end
    RateLimiter.disable
    options[:num_topics].times do
      topic = Topic.find_by(id: options[:topic_id])
      start_post = 1
      topic = create_topic(users) unless topic
      puts "Adding posts to '#{topic.title}'"
      puts "Making #{options[:num_posts]} posts"
      (start_post..options[:num_posts]).each do
        create_post(users, topic)
      end
      puts ''
      puts "Done. Topic id = #{topic.id}"
    end
  ensure
    RateLimiter.enable
  end

  private

  def create_user(user_email)
    user = User.find_by_email(user_email)
    unless user
      puts "Creating new account: #{user_email}"
      user = User.create!(email: user_email, password: SecureRandom.hex, username: UserNameSuggester.suggest(user_email))
    end
    user.active = true
    user.save!
    user
  end

  def create_topic(users)
    topic_title = options[:title] || generate_sentence(5)
    puts "Making a new topic: '#{topic_title}'"
    post_creator = PostCreator.new(users.sample, title: topic_title, raw: generate_sentence(7))
    first_post = post_creator.create
    unless first_post
      puts post_creator.errors.full_messages, ""
      raise StandardError.new(post_creator.errors.full_messages)
    end
    topic = first_post.topic
    start_post = 2
    topic
  end

  def create_post(users, topic)
    print '.'
    raw = rand(4) == 0 ? (rand(2) == 0 ? image_posts.sample : wikipedia_posts.sample) : generate_sentence(7)
    post_creator = PostCreator.new(users.sample, topic_id: topic.id, raw: raw)
    post = post_creator.create
    unless post
      puts post_creator.errors.full_messages, ""
    end
    post
  end

  def hipster_words
    @hipster_words ||= ['etsy', 'twee', 'hoodie', 'Banksy', 'retro', 'synth', 'single-origin', 'coffee', 'art', 'party', 'cliche', 'artisan', 'Williamsburg', 'squid', 'helvetica', 'keytar', 'American Apparel', 'craft beer', 'food truck', "you probably haven't heard of them", 'cardigan', 'aesthetic', 'raw denim', 'sartorial', 'gentrify', 'lomo', 'Vice', 'Pitchfork', 'Austin', 'sustainable', 'salvia', 'organic', 'thundercats', 'PBR', 'iPhone', 'lo-fi', 'skateboard', 'jean shorts', 'next level', 'beard', 'tattooed', 'trust fund', 'Four Loko', 'master cleanse', 'ethical', 'high life', 'wolf moon', 'fanny pack', 'Terry Richardson', '8-bit', 'Carles', 'Shoreditch', 'seitan', 'freegan', 'keffiyeh', 'biodiesel', 'quinoa', 'farm-to-table', 'fixie', 'viral', 'chambray', 'scenester', 'leggings', 'readymade', 'Brooklyn', 'Wayfarers', 'Marfa', 'put a bird on it', 'dreamcatcher', 'photo booth', 'tofu', 'mlkshk', 'vegan', 'vinyl', 'DIY', 'banh mi', 'bicycle rights', 'before they sold out', 'gluten-free', 'yr butcher blog', 'whatever', '+1', 'Cosby Sweater', 'VHS', 'messenger bag', 'cred', 'locavore', 'mustache', 'tumblr', 'Portland', 'mixtape', 'fap', 'letterpress', "McSweeney's", 'stumptown', 'brunch', 'Wes Anderson', 'irony', 'echo park']
  end

  def generate_sentence(num_words)
    sentence = hipster_words.sample(num_words).join(' ').capitalize + '.'
    sentence.force_encoding('UTF-8')
  end

  def generate_email
    email = hipster_words.sample.delete(' ') + '@' + hipster_words.sample.delete(' ') + '.com'
    email.delete("'").force_encoding('UTF-8')
  end

  def image_posts
    @image_posts ||= ["http://i.imgur.com/CnRF48R.jpg\n\n", "http://i.imgur.com/2iaeK.png\n\n", "http://i.imgur.com/WSD5t61.jpg\n\n", "http://i.imgur.com/GUldmUd.jpg\n\n", "http://i.imgur.com/nJnb6Bj.jpg\n\n", "http://i.imgur.com/eljDYjm.jpg\n\n", "http://i.imgur.com/5yZMWyY.png\n\n", "http://i.imgur.com/2iCPGm2.jpg\n\n"]
  end

  def wikipedia_posts
    @wikipedia_posts ||= ["http://en.wikipedia.org/wiki/Dwarf_fortress\n\n", "http://en.wikipedia.org/wiki/Action_plan\n\n", "http://en.wikipedia.org/wiki/Chang%27e_3\n\n", "http://en.wikipedia.org/wiki/Carl_sagan\n\n", "http://en.wikipedia.org/wiki/Chasmosaurus\n\n", "http://en.wikipedia.org/wiki/Indian_Space_Research_Organisation\n\n", "http://en.wikipedia.org/wiki/Rockstar_Consortium\n\n", "http://en.wikipedia.org/wiki/Manitoulin_island\n\n"]
  end
end
