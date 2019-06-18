# frozen_string_literal: true

###
###
### The output of this importer is bad.
###
### Improving it means getting better quality export data from Zoho,
### or doing a lot more work on this importer.
###
### Consider leaving data in Zoho and starting fresh in Discourse.
###
###

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
    create_users(CSV.parse(File.read(File.join(@path, 'users.csv')))) do |u|
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
      c = create_category({ name: parent }, parent)
      subcats.each do |subcat|
        next if subcat == "Uncategorized" || subcat == "Uncategorised"
        create_category({ name: subcat, parent_category_id: c.id }, "#{parent}:#{subcat}")
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
          title: CGI.unescapeHTML(row.topic_title),
          raw: cleanup_post(row.content),
          created_at: Time.zone.parse(row.posted_time)
        }
        # created_post callback will be called
      else
        {
          id: import_post_id(row),
          user_id: user_id,
          raw: cleanup_post(row.content),
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

  # Note that Zoho doesn't render code blocks the same way all the time,
  # but this seems to catch the most common format:
  ZOHO_CODE_BLOCK_START = /<ol style="list-style-position: outside;(.)*">/

  TOO_MANY_LINE_BREAKS = /[\n ]{3,}/
  STYLE_ATTR = /(\s)*style="(.)*"/

  def cleanup_post(raw)

    # Check if Zoho's most common form of a code block is present.
    # If so, don't clean up the post as much because we can't tell which markup
    # is inside the code block. These posts will look worse than others.
    has_code_block = !!(raw =~ ZOHO_CODE_BLOCK_START)

    x = raw.gsub(STYLE_ATTR, '')

    if has_code_block
      # We have to assume all lists in this post are meant to be code blocks
      # to make it somewhat readable.
      x.gsub!(/( )*<ol>(\s)*/, "")
      x.gsub!(/( )*<\/ol>/, "")
      x.gsub!('<li>', '')
      x.gsub!('</li>', '')
    else
      # No code block (probably...) so clean up more aggressively.
      x.gsub!("\n", " ")
      x.gsub!('<div>', "\n\n")
      x.gsub('</div>', ' ')
      x.gsub!("<br />", "\n")
      x.gsub!('<span>', '')
      x.gsub!('</span>', '')
      x.gsub!(/<font ([^>]*)>/, '')
      x.gsub!('</font>', '')
    end

    x.gsub!(TOO_MANY_LINE_BREAKS, "\n\n")

    CGI.unescapeHTML(x)
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
