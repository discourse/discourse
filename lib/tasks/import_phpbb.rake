############################################################
#### IMPORT phpBB to Discourse
####
#### originally created for facebook by Sander Datema (info@sanderdatema.nl)
#### forked by Claus F. Strasburger ( http://about.me/cfstras )
####
#### version 0.2
############################################################

############################################################
#### Description
############################################################
#
# This rake task will import all posts and comments of a
# phpBB Forum into Discourse.
#
############################################################
#### Prerequisits
############################################################
#
# - Add this to your Gemfile:
#   gem 'mysql2', require: false
# - Edit the configuration file config/import_phpbb.yml

############################################################
#### The Rake Task
############################################################

require 'mysql2'

desc "Import posts and comments from a phpBB Forum"
task "import:phpbb" => 'environment' do
  # Import configuration file
  @config = YAML.load_file('config/import_phpbb.yml')
  TEST_MODE = @config['test_mode']
  DC_ADMIN = @config['discourse_admin']
  MARKDOWN_LINEBREAKS = true

  if TEST_MODE then puts "\n*** Running in TEST mode. No changes to Discourse database are made\n".yellow end

  # Some checks
  # Exit rake task if admin user doesn't exist
  if Discourse.system_user.nil?
    unless dc_user_exists(DC_ADMIN) then
      puts "\nERROR: The admin user #{DC_ADMIN} does not exist".red
      exit_script
    else
      DC_ADMIN = dc_get_user(DC_ADMIN)
    end
  else
    DC_ADMIN = Discourse.system_user
  end

  begin
    # ask for markdown setting

    input = ''
    puts "Do you want to enable traditional markdown-linebreaks? (linebreaks are ignored unless the line ends with two spaces)"
    print "y/N? >"
    input = STDIN.gets.chomp
    MARKDOWN_LINEBREAKS = ( /y(es)?/i.match(input) or input.empty? )

    puts "Using markdown linebreaks: "+MARKDOWN_LINEBREAKS.to_s

    sql_connect

    sql_fetch_users
    sql_fetch_posts

    if TEST_MODE then
      begin
        require 'irb'
        ARGV.clear
        IRB.start
      rescue :IRB_EXIT
      end
      
      exit_script # We're done
    else
      # Backup Site Settings
      dc_backup_site_settings
      # Then set the temporary Site Settings we need
      dc_set_temporary_site_settings
      # Create users in Discourse
      create_users

      # Import posts into Discourse
      sql_import_posts

      # Restore Site Settings
      dc_restore_site_settings
    end
  ensure
    @sql.close if @sql
  end
  puts "\n*** DONE".green
  # DONE!
end


############################################################
#### Methods
############################################################

def sql_connect
  begin
    @sql = Mysql2::Client.new(:host => @config['sql_server'], :username => @config['sql_user'],
      :password => @config['sql_password'], :database => @config['sql_database'])
  rescue Mysql2::Error => e
    puts "\nERROR: Connection to Database failed\n#{e.message}".red
    exit_script
  end

  puts "\nConnected to SQL DB".green
end

def sql_fetch_posts
  @phpbb_posts ||= [] # Initialize if needed
  offset = 0

  # Fetch Facebook posts in batches and download writer/user info
  loop do
    query = "SELECT t.topic_id, t.topic_title,
      u.username, u.user_id,
      f.forum_name,
      p.post_time, p.post_edit_time,
      p.post_id,
      p.post_text
      FROM phpbb_posts p
      JOIN phpbb_topics t ON t.topic_id=p.topic_id
      JOIN phpbb_users u ON u.user_id=p.poster_id
      JOIN phpbb_forums f ON t.forum_id=f.forum_id
      ORDER BY topic_id ASC, topic_title ASC, post_id ASC
      LIMIT #{offset.to_s},500;"
    puts query.yellow if offset == 0
    result = @sql.query query
    
    count = 0
    # Add the results of this batch to the rest of the imported posts
    result.each do |post|
      @phpbb_posts << post
      count += 1
    end
    
    puts "Batch: #{count.to_s} posts".green
    offset += count
    break if count == 0 or count < 500 # No more posts to import
  end

  puts "\nAmount of posts: #{@phpbb_posts.count.to_s}".green
end

def sql_fetch_users
  @phpbb_users ||= [] # Initialize if needed

  offset = 0
  loop do
    count = 0
    query = "SELECT user_id, username_clean, username,
      user_email, user_posts, user_inactive_reason, user_lastvisit, group_name
      FROM phpbb_users u
      JOIN phpbb_groups g ON g.group_id = u.group_id
      WHERE g.group_name != 'BOTS'
      ORDER BY u.user_id ASC
      LIMIT #{offset}, 50;"
    puts query.yellow if offset == 0
    users = @sql.query query
    users.each do |user|
      @phpbb_users << user
      count += 1
    end
    offset += count
    break if count == 0
  end
  puts "Amount of users: #{@phpbb_users.count.to_s}".green
end

def sql_import_posts
  post_count = 0
  topics = {}
  @phpbb_posts.each do |phpbb_post|
    post_count += 1

    # Get details of the writer of this post
    user = @phpbb_users.find {|k| k['user_id'] == phpbb_post['user_id']}
    
    if user.nil?
      puts "Warning: User (#{phpbb_post['user_id']}) {phpbb_post['username']} not found in user list!"
    end
    
    # Get the Discourse user of this writer
    dc_user = dc_get_user(phpbb_username_to_dc(user['username_clean']))
    category = create_category(
      phpbb_post['forum_name'].downcase, DC_ADMIN)
    topic_title = sanitize_topic phpbb_post['topic_title']
    # Remove new lines and replace with a space
    # topic_title = topic_title.gsub( /\n/m, " " )
    
    # are we creating a new topic?
    is_new_topic = false
    topic = topics[phpbb_post['topic_id']]
    if topic.nil?
      is_new_topic = true
    end
    
    # some progress
    progress = post_count.percent_of(@phpbb_posts.count).round.to_s
    
    text = sanitize_text phpbb_post['post_text']
    
    # create!
    post_creator = nil
    if is_new_topic
      print "\n[#{progress}%] Creating topic ".yellow + topic_title +
        " (#{Time.at(phpbb_post['post_time'])}) in category ".yellow +
        "#{category.name}"
      post_creator = PostCreator.new(
        dc_user,
        raw: text,
        title: topic_title,
        archetype: 'regular',
        category: category.name,
        created_at: Time.at(phpbb_post['post_time']),
        updated_at: Time.at(phpbb_post['post_edit_time']))

      # for a new topic: also clear mail deliveries
      ActionMailer::Base.deliveries = []
    else
      print ".".yellow
      $stdout.flush
      post_creator = PostCreator.new(
        dc_user,
        raw: text,
        topic_id: topic,
        created_at: Time.at(phpbb_post['post_time']),
        updated_at: Time.at(phpbb_post['post_edit_time']))
    end
    post = nil
    begin
      post = post_creator.create
    rescue Exception => e
      puts "Error #{e} on post #{phpbb_post['post_id']}:\n#{text}"
      puts "--"
      puts e.inspect
      puts e.backtrace
      abort
    end
    # Everything set, save the topic
    if post_creator.errors.present? # Skip if not valid for some reason
      puts "\nContents of topic from post #{phpbb_post['post_id']} failed to ".red+
               "import: #{post_creator.errors.full_messages}".red
    else
      post_serializer = PostSerializer.new(post, scope: true, root: false)
      post_serializer.topic_slug = post.topic.slug if post.topic.present?
      post_serializer.draft_sequence = DraftSequence.current(dc_user, post.topic.draft_key)
      #save id to hash
      topics[phpbb_post['topic_id']] = post.topic.id if is_new_topic
      puts "\nTopic #{phpbb_post['post_id']} created".green if is_new_topic
    end
  end
end


# Returns the Discourse category where imported posts will go
def create_category(name, owner)
  if Category.where('name = ?', name).empty? then
    puts "\nCreating category '#{name}'".yellow
    Category.create!(name: name, user_id: owner.id)
  else
    # puts "Category '#{name}'".yellow
    Category.where('name = ?', name).first
  end
end

# Create a Discourse user with Facebook info unless it already exists
def create_users
  @phpbb_users.each do |phpbb_user|
    # Setup Discourse username
    dc_username = phpbb_username_to_dc(phpbb_user['username_clean'])
    
    dc_email = phpbb_user['user_email']
    # Create email address for user
    if dc_email.nil? or dc_email.empty? then
      dc_email = dc_username + "@has.no.email"
    end

    approved = phpbb_user['user_inactive_reason'] == 0
    approved_by_id =  if approved
                        DC_ADMIN.id
                      else
                        nil
                      end

    admin = if phpbb_user['group_name'] == 'ADMINISTRATORS'
            true
              else
            false
              end

    # Create user if it doesn't exist
    if User.where('username = ?', dc_username).empty? then

      begin
        dc_user = User.create!(username: dc_username,
                               name: phpbb_user['username'],
                               email: dc_email,
                               active: phpbb_user['user_posts'] > 0,
                               approved: approved,
                               approved_by_id: approved_by_id,
                               admin: admin,
                               last_seen_at: Time.at(phpbb_user['user_lastvisit']))
      rescue Exception => e
        puts "Error #{e} on user #{dc_username} <#{dc_email}>"
        puts "--"
        puts e.inspect
        puts e.backtrace
        abort
      end
      #TODO: add authentication info
      puts "User (#{phpbb_user['user_id']}) #{phpbb_user['username']} (#{dc_username} / #{dc_email}) created".green
    else
      puts "User (#{phpbb_user['user_id']}) #{phpbb_user['username']} (#{dc_username} / #{dc_email}) found".green
    end
  end
end

def sanitize_topic(text)
  CGI.unescapeHTML(text)
end

def sanitize_text(text)
  text = CGI.unescapeHTML(text)

  # screaming
  unless seems_quiet?(text)
    text = '<capslock> ' + text.downcase
  end

  unless seems_pronounceable?(text)
    text = "<symbols>\n" + text
  end

  # remove tag IDs
  text.gsub! /\[(\/?[a-zA-Z]+(=("[^"]*?"|[^\]]*?))?):[a-z0-9]+\]/, '[\1]'

  # completely remove youtube, soundcloud and url tags as those links are oneboxed
  text.gsub! /\[(youtube|soundcloud|url|img)\](.*?)\[\/\1\]/m, "\n"+'\2'+"\n"

  # yt tags are custom for our forum
  text.gsub! /\[yt\]([a-zA-Z0-9_-]{11})\[\/yt\]/, ' http://youtu.be/\1 '

  # convert newlines to markdown syntax
  text.gsub! /([^\n])\n/, '\1  '+"\n" if MARKDOWN_LINEBREAKS
  
  # edit invalid quotes
  text.gsub! /\[quote\]/, '[quote=""]'
  
  # strange links (maybe soundcloud)
  # <!-- m --><a class="postlink" href="http://link">http://link</a><!-- m -->
  text.gsub! /<!-- m --><a class="postlink" href="(.*?)">.*?<\/a><!-- m -->/m, ' \1 '

  # convert code blocks to markdown syntax
  text.gsub! /\[code\](.*?)\[\/code\]/m do |match|
    "\n    " + $1.gsub(/(  )?\n(.)/, "\n"+'    \2') + "\n"
  end

  # size tags
  # discourse likes numbers from 4-40 (pt), phpbb uses 20 to 200 (percent)
  # [size=85:az5et819]dump dump[/size:az5et819]
  text.gsub! /\[size=(\d+)(%?)\]/ do |match|
    pt = $1.to_i / 100 * 14 # 14 is the default text size
    pt = 40 if pt > 40
    pt = 4 if pt < 4

    "[size=#{pt}]"
  end

  text
end


### Methods stolen from lib/text_sentinel.rb
def seems_quiet?(text)
  # We don't allow all upper case content in english
  not((text =~ /[A-Z]+/) && !(text =~ /[^[:ascii:]]/) && (text == text.upcase))
end
def seems_pronounceable?(text)
  # At least some non-symbol characters
  # (We don't have a comprehensive list of symbols, but this will eliminate some noise)
  text.gsub(symbols_regex, '').size > 0
end
def symbols_regex
  /[\ -\/\[-\`\:-\@\{-\~]/m
end
###

# Backup site settings
def dc_backup_site_settings
  s = {}
  #Discourse::Application.configure do
  #  s['mailer'] = config.action_mailer.perform_deliveries
  #  s['method'] = config.action_mailer.delivery_method
  #  s['errors'] = config.action_mailer.raise_delivery_errors = false
  #end
  
  s['unique_posts_mins'] = SiteSetting.unique_posts_mins
  s['rate_limit_create_topic'] = SiteSetting.rate_limit_create_topic
  s['rate_limit_create_post'] = SiteSetting.rate_limit_create_post
  s['max_topics_per_day'] = SiteSetting.max_topics_per_day
  s['title_min_entropy'] = SiteSetting.title_min_entropy
  s['body_min_entropy'] = SiteSetting.body_min_entropy
  
  s['min_post_length'] = SiteSetting.min_post_length
  s['newuser_spam_host_threshold'] = SiteSetting.newuser_spam_host_threshold
  s['min_topic_title_length'] = SiteSetting.min_topic_title_length
  s['newuser_max_links'] = SiteSetting.newuser_max_links
  s['newuser_max_images'] = SiteSetting.newuser_max_images
  s['max_word_length'] = SiteSetting.max_word_length
  s['email_time_window_mins'] = SiteSetting.email_time_window_mins
  s['max_topic_title_length'] = SiteSetting.max_topic_title_length
  #s['abc'] = SiteSetting.abc
  
  @site_settings = s
end

# Restore site settings
def dc_restore_site_settings
  s = @site_settings
  #Discourse::Application.configure do
  #  config.action_mailer.perform_deliveries = s['mailer']
  #  config.action_mailer.delivery_method = s['method']
  #  config.action_mailer.raise_delivery_errors = s['errors']
  #end
  SiteSetting.send("unique_posts_mins=", s['unique_posts_mins'])
  SiteSetting.send("rate_limit_create_topic=", s['rate_limit_create_topic'])
  SiteSetting.send("rate_limit_create_post=", s['rate_limit_create_post'])
  SiteSetting.send("max_topics_per_day=", s['max_topics_per_day'])
  SiteSetting.send("title_min_entropy=", s['title_min_entropy'])
  SiteSetting.send("body_min_entropy=", s['body_min_entropy'])
    
  SiteSetting.send("min_post_length=", s['min_post_length'])
  SiteSetting.send("newuser_spam_host_threshold=", s['newuser_spam_host_threshold'])
  SiteSetting.send("min_topic_title_length=", s['min_topic_title_length'])
  SiteSetting.send("newuser_max_links=", s['newuser_max_links'])
  SiteSetting.send("newuser_max_images=", s['newuser_max_images'])
  SiteSetting.send("max_word_length=", s['max_word_length'])
  SiteSetting.send("email_time_window_mins=", s['email_time_window_mins'])
  SiteSetting.send("max_topic_title_length=", s['max_topic_title_length'])
  #SiteSetting.send("abc=", s['abc'])
end

# Set temporary site settings needed for this rake task
def dc_set_temporary_site_settings
  # don't backup this first one
  SiteSetting.send("traditional_markdown_linebreaks=", MARKDOWN_LINEBREAKS)

  SiteSetting.send("unique_posts_mins=", 0)
  SiteSetting.send("rate_limit_create_topic=", 0)
  SiteSetting.send("rate_limit_create_post=", 0)
  SiteSetting.send("max_topics_per_day=", 10000)
  SiteSetting.send("title_min_entropy=", 0)
  SiteSetting.send("body_min_entropy=", 0)
  
  SiteSetting.send("min_post_length=", 1) # never set this to 0
  SiteSetting.send("newuser_spam_host_threshold=", 1000)
  SiteSetting.send("min_topic_title_length=", 2)
  SiteSetting.send("max_topic_title_length=", 512)
  SiteSetting.send("newuser_max_links=", 1000)
  SiteSetting.send("newuser_max_images=", 1000)
  SiteSetting.send("max_word_length=", 5000)
  SiteSetting.send("email_time_window_mins=", 1)
  #SiteSetting.send("abc=", 0)
end

# Check if user exists
# For some really weird reason this method returns the opposite value
# So if it did find the user, the result is false
def dc_user_exists(name)
  User.where('username = ?', name).exists?
end

def dc_get_user_id(name)
  User.where('username = ?', name).first.id
end

def dc_get_user(name)
  User.where('username = ?', name).first
end

# Returns current unix time
def current_unix_time
  Time.now.to_i
end

def unix_to_human_time(unix_time)
  Time.at(unix_time).strftime("%d/%m/%Y %H:%M")
end

# Exit the script
def exit_script
  puts "\nScript will now exit\n".yellow
  abort
end

def phpbb_username_to_dc(name)
  # Create username from full name, only letters and numbers
  username = name.tr('^A-Za-z0-9', '').downcase
  # Maximum length of a Discourse username is 15 characters
  username = username[0,15]
end

# Add colors to class String
class String
  def red
    colorize(self, 31);
  end

  def green
    colorize(self, 32);
  end

  def yellow
    colorize(self, 33);
  end

  def blue
    colorize(self, 34);
  end

  def colorize(text, color_code)
    "\033[#{color_code}m#{text}\033[0m"
  end
end

# Calculate percentage
class Numeric
  def percent_of(n)
    self.to_f / n.to_f * 100.0
  end
end
