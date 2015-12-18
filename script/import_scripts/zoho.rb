# Import from Zoho.
# Be sure to get the posts CSV file, AND the user list csv file with people's email addresses.
# You may need to contact Zoho support for the user list.
#
# * Zoho data doesn't indicate which users are admins or moderators, so you'll need to grant
#   those privileges manually after the import finishes.
# * The posts and users csv files don't seem to have consistent usernames, and sometimes use
#   full names instead of usernames. This may cause duplicate users with slightly different
#   usernames to be created.

require 'csv'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require File.expand_path(File.dirname(__FILE__) + "/base/csv_helper.rb")

# Call it like this:
#   bundle exec ruby script/import_scripts/zoho.rb <path-to-csv-files>
class ImportScripts::Zoho < ImportScripts::Base

  include ImportScripts::CsvHelper

  BATCH_SIZE = 1000

  def initialize(path)
    @path = path
    @all_posts = []
    @categories = {} # key is the parent category, value is an array of sub-categories
    @topic_mapping = {}
    @current_row = nil
    super()
  end

  def execute
    import_users
    import_posts
    update_tl0
    update_user_signup_date_based_on_first_post
  end

  def cleanup_zoho_username(s)
    s.strip.gsub(/[^A-Za-z0-9_\.\-]/, '')
  end

  def import_users
    puts "", "Importing users"
    create_users( CSV.parse(File.read(File.join(@path, 'users.csv'))) ) do |u|
      username = cleanup_zoho_username(u[0])
      {
        id: username,
        username: username,
        email: u[1],
        created_at: Time.zone.now
      }
    end
  end

  def import_posts
    # 0 Forum Name
    # 1 Category Name
    # 2 Topic Title
    # 3 Permalink
    # 4 Posted Time
    # 5 Content
    # 6 Author
    # 7 Attachments
    # 8 Votes

    count = 0

    puts "", "Parsing posts CSV"

    csv_parse(File.join(@path, "posts.csv")) do |row|
      @all_posts << row.dup
      if @categories[row.forum_name].nil?
        @categories[row.forum_name] = []
      end

      unless @categories[row.forum_name].include?(row.category_name)
        @categories[row.forum_name] << row.category_name
      end
    end

    puts "", "Creating categories"

    # Create categories
    @categories.each do |parent, subcats|
      c = create_category({name: parent}, parent)
      subcats.each do |subcat|
        next if subcat == "Uncategorized" || subcat == "Uncategorised"
        create_category({name: subcat, parent_category_id: c.id}, "#{parent}:#{subcat}")
      end
    end

    puts "", "Creating topics and posts"

    created, skipped = create_posts(@all_posts, total: @all_posts.size) do |row|
      @current_row = row

      # fetch user
      username = cleanup_zoho_username(row.author)

      next if username.blank? # no author for this post, so skip

      user_id = user_id_from_imported_user_id(username)

      if user_id.nil?
        # user CSV file didn't have a user with this username. create it now with an invalid email address.
        u = create_user(
          { id: username,
            username: username,
            email: "#{username}@example.com",
            created_at: Time.zone.parse(row.posted_time) },
          username
        )
        user_id = u.id
      end

      if @topic_mapping[row.permalink].nil?
        category_id = nil
        if row.category_name != "Uncategorized" && row.category_name != "Uncategorised"
          category_id = category_id_from_imported_category_id("#{row.forum_name}:#{row.category_name}")
        else
          category_id = category_id_from_imported_category_id(row.forum_name)
        end

        # create topic
        {
          id: import_post_id(row),
          user_id: user_id,
          category: category_id,
          title: row.topic_title,
          raw: row.content,
          created_at: Time.zone.parse(row.posted_time)
        }
        # created_post callback will be called
      else
        {
          id: import_post_id(row),
          user_id: user_id,
          raw: row.content,
          created_at: Time.zone.parse(row.posted_time),
          topic_id: @topic_mapping[row.permalink]
        }
      end
    end

    puts ""
    puts "Created: #{created}"
    puts "Skipped: #{skipped}"
    puts ""
  end

  def created_post(post)
    unless @topic_mapping[@current_row.permalink]
      @topic_mapping[@current_row.permalink] = post.topic_id
    end
  end

  def import_post_id(row)
    # Try to make up a unique id based on the data Zoho gives us.
    # The posted_time seems to be the same for all posts in a topic, so we can't use that.
    Digest::SHA1.hexdigest "#{row.permalink}:#{row.content}"
  end

end

unless ARGV[0] && Dir.exist?(ARGV[0])
  if ARGV[0] && !Dir.exist?(ARGV[0])
    puts "", "ERROR! Dir #{ARGV[0]} not found.", ""
  end

  puts "", "Usage:", "", "    bundle exec ruby script/import_scripts/zoho.rb DIRNAME", ""
  exit 1
end

ImportScripts::Zoho.new(ARGV[0]).perform
