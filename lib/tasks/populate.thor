class Populate < Thor

  MAX_ERRORS = 5

  desc "posts", "Generate posts in a topic"
  long_desc <<-LONGDESC
    Create a topic with any number of posts, or add posts to an existing topic.

    Examples:

    Create a new topic with 100 posts from batman and spiderman:

    > $ thor populate:posts -n 100 -u batman spiderman -t "So many posts"

    Add 10 posts to topic with id 123:

    > $ thor populate:posts -n 10 -u batman spiderman -i 123

  LONGDESC
  method_option :num_posts, aliases: '-n',  type: :numeric, required: true, desc: "Number of posts to make"
  method_option :users,     aliases: '-u',  required: true, type: :array, desc: "Usernames of users who will make the posts"
  method_option :title,     aliases: '-t',  desc: "The title of the topic, if making a new topic"
  method_option :topic_id,  aliases: '-i', type: :numeric, desc: "The id of the topic where the posts will be added"
  def posts
    require './config/environment'

    users = options[:users].map { |u| User.find_by_username(u.downcase) }
    if users.length != options[:users].length
      not_found = options[:users].map(&:downcase) - users.map(&:username_lower)
      puts "No user found for these usernames: #{not_found.join(', ')}"
      exit 1
    end

    RateLimiter.disable

    topic = nil
    start_post = 1
    if options[:topic_id]
      topic = Topic.find(options[:topic_id])
      puts "Adding more posts to '#{topic.title}'"
    else
      topic_title = options[:title] || hipster_words.sample(6).join(' ')

      puts "Making a new topic: '#{topic_title}'"

      post_creator = PostCreator.new(users[0], title: topic_title, raw: hipster_words.sample(10).join(' '))
      first_post = post_creator.create
      if post_creator.errors.present?
        puts "ERROR creating the topic!"
        puts post_creator.errors.full_messages
        exit 1
      end
      topic = first_post.topic
      start_post = 2
    end

    puts "Making #{options[:num_posts]} posts"

    num_errors = 0

    (start_post..options[:num_posts]).each do |num|
      print '.'
      raw = rand(4) == 0 ? (rand(2) == 0 ? image_posts.sample : wikipedia_posts.sample ) : hipster_words.sample(20).join(' ')
      post_creator = PostCreator.new(users[num % (users.length)], topic_id: topic.id, raw: raw)
      post_creator.create
      if post_creator.errors.present?
        # It's probably a "Body is too similar to what you recently posted" error.
        # Try one more time using more random words.
        post_creator = PostCreator.new(users[num % (users.length)], topic_id: topic.id, raw: hipster_words.sample(40).join(' '))
        post_creator.create
        if post_creator.errors.present?
          # Still failing! Show the error.
          puts '', "--------------------------"
          puts "ERROR creating a post!"
          puts post_creator.errors.full_messages
          puts "--------------------------"

          # Stop looping after MAX_ERRORS errors
          num_errors += 1
          if num_errors > MAX_ERRORS
            puts "Giving up. Too many errors."
            exit 1
          end
        end
      end
    end

    puts ''

    puts "Done. Topic id = #{topic.id}"
  ensure
    RateLimiter.enable
  end

  private

    def hipster_words
      @hipster_words ||= "retro put a bird on it wolf vegan gluten-free swag trust fund master cleanse four loko synth gentrify literally lomo bitters Keytar try-hard semiotics gastropub marfa YOLO bicycle rights street art authentic DIY fashion axe Chia letterpress twee mlkshk Typewriter umami Etsy keffiyeh direct trade Distillery Odd Future narwhal Pitchfork roof party pork belly Austin McSweeney's cliche Dreamcatcher +1 drinking vinegar Neutra Vice pickled Brooklyn Williamsburg hella small batch ennui squid Schlitz Kale chips food truck butcher vinyl ethnic fixie shabby chic iPhone Terry Richardson Deep v hoodie forage Retro fanny pack wayfarers messenger bag pug you probably haven't heard of them Art disrupt High Life hashtag chambray readymade selfies sartorial PBR leggings flexitarian chillwave Cosby sweater Marfa typewriter freegan chia biodiesel 8-bit occupy Tonx sustainable cray PBR&B Yr skateboard Tumblr 3 moon fingerstache Intelligentsia plaid Thundercats XOXO craft beer mustache Shoreditch Next level Godard actually mumblecore keytar stumptown irony Disrupt tofu scenester lo-fi single-origin coffee kogi beard yr tattooed viral 90's aesthetic pop-up mixtape Pinterest Asymmetrical kitsch farm-to-table photo booth cardigan Squid Helvetica Direct kale salvia American Apparel artisan tousled".split(' ') +
                          (["\n\n"] * 20)
    end

    def image_posts
      @image_posts ||= ["http://i.imgur.com/CnRF48R.jpg\n\n", "http://i.imgur.com/2iaeK.png\n\n", "http://i.imgur.com/WSD5t61.jpg\n\n", "http://i.imgur.com/GUldmUd.jpg\n\n", "http://i.imgur.com/nJnb6Bj.jpg\n\n", "http://i.imgur.com/eljDYjm.jpg\n\n", "http://i.imgur.com/5yZMWyY.png\n\n", "http://i.imgur.com/2iCPGm2.jpg\n\n"]
    end

    def wikipedia_posts
      @wikipedia_posts ||= ["http://en.wikipedia.org/wiki/Dwarf_fortress\n\n", "http://en.wikipedia.org/wiki/Action_plan\n\n", "http://en.wikipedia.org/wiki/Chang%27e_3\n\n", "http://en.wikipedia.org/wiki/Carl_sagan\n\n", "http://en.wikipedia.org/wiki/Chasmosaurus\n\n", "http://en.wikipedia.org/wiki/Indian_Space_Research_Organisation\n\n", "http://en.wikipedia.org/wiki/Rockstar_Consortium\n\n", "http://en.wikipedia.org/wiki/Manitoulin_island\n\n"]
    end
end
