require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'mongo'

# Import YahooGroups data as exported into MongoDB by:
#   https://github.com/jonbartlett/yahoo-groups-export
#
#   Optionally paste these lines into your shell before running this:
#
#   =begin
#   export CATEGORY_ID=<CATEGORY_ID>
#   =end

class ImportScripts::YahooGroup < ImportScripts::Base

  MONGODB_HOST = '192.168.10.1:27017'
  MONGODB_DB   = 'syncro'

  def initialize
    super

    client = Mongo::Client.new([ MONGODB_HOST ], database: MONGODB_DB)
    db = client.database
    Mongo::Logger.logger.level = Logger::FATAL
    puts "connected to db...."

    @collection = client[:posts]

    @user_profile_map = {}

  end

  def execute
    puts "", "Importing from Mongodb...."

    import_users
    import_discussions

    puts "", "Done"
  end

  def import_users

    puts '', "Importing users"

    # fetch distinct list of Yahoo "profile" names
    profiles = @collection.aggregate(
                 [
                  { "$group": { "_id": { profile: "$ygData.profile"  } } }
                 ]
            )

    user_id = 0

    create_users(profiles.to_a) do |u|

      user_id = user_id + 1

      # fetch last message for profile to pickup latest user info as this may have changed
      user_info = @collection.find("ygData.profile": u["_id"]["profile"]).sort("ygData.msgId": -1).limit(1).to_a[0]

      # Store user_id to profile lookup
      @user_profile_map.store(user_info["ygData"]["profile"], user_id)

      puts "User created: #{user_info["ygData"]["profile"]}"

      user =
       {
        id: user_id,  # yahoo "userId" sequence appears to have changed mid forum life so generate this
        username: user_info["ygData"]["profile"],
        name: user_info["ygData"]["authorName"],
        email: user_info["ygData"]["from"], # mandatory
        created_at: Time.now
      }
      user
    end

    puts "#{user_id} users created"

  end

  def import_discussions
    puts "", "Importing discussions"

    topics_count = 0
    posts_count = 0

    topics = @collection.aggregate(
                 [
                  { "$group": { "_id": { topicId: "$ygData.topicId"  } } }
                 ]
    ).to_a

    # for each distinct topicId found
    topics.each_with_index do |t, tidx|

      # create "topic" post first.
      # fetch topic document
      topic_post = @collection.find("ygData.msgId": t["_id"]["topicId"]).to_a[0]
      next if topic_post.nil?

      puts "Topic: #{tidx + 1} / #{topics.count()}  (#{sprintf('%.2f', ((tidx + 1).to_f / topics.count().to_f) * 100)}%)  Subject: #{topic_post["ygData"]["subject"]}"

      if topic_post["ygData"]["subject"].to_s.empty?
        topic_title = "No Subject"
      else
        topic_title = topic_post["ygData"]["subject"]
      end

      topic = {
        id: tidx + 1,
        user_id: @user_profile_map[topic_post["ygData"]["profile"]] || -1,
        raw: topic_post["ygData"]["messageBody"],
        created_at: Time.at(topic_post["ygData"]["postDate"].to_i),
        cook_method: Post.cook_methods[:raw_html],
        title: topic_title,
        category: ENV['CATEGORY_ID'],
        custom_fields: { import_id: topic_post["ygData"]["msgId"] }
      }

      topics_count += 1

      # create topic post
      parent_post = create_post(topic, topic[:id])

      # find all posts for topic id
      posts = @collection.find("ygData.topicId": topic_post["ygData"]["topicId"]).to_a

      posts.each_with_index do |p, pidx|

        # skip over first post as this is created by topic above
        next if p["ygData"]["msgId"] == topic_post["ygData"]["topicId"]

        puts "  Post: #{pidx + 1} / #{posts.count()}"

        post = {
             id: pidx + 1,
             topic_id: parent_post[:topic_id],
             user_id: @user_profile_map[p["ygData"]["profile"]] || -1,
             raw: p["ygData"]["messageBody"],
             created_at: Time.at(p["ygData"]["postDate"].to_i),
             cook_method: Post.cook_methods[:raw_html],
             custom_fields: { import_id: p["ygData"]["msgId"] }
        }

        child_post = create_post(post, post[:id])

        posts_count += 1

      end

    end

    puts "", "Imported #{topics_count} topics with #{topics_count + posts_count} posts."

  end

end

ImportScripts::YahooGroup.new.perform
