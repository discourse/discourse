require "date"
require "nokogiri"
require "open-uri"
require "securerandom"

if ARGV.empty?
  puts "usage: #{__FILE__} <forumname>"
end

@users = {}
@post_mapping = {}

def get(url)
  begin
    retries ||= 0
    open(url).read
  rescue
    sleep retries
    retry if (retries += 1) < 3
  end
end

def crawl_topics(url)
  doc = Nokogiri::HTML get(url)
  topic_ids = doc.css(".threadUrl").map { |a| a.attributes["data-threadid"].value }
  topic_ids.each { |topic_id| crawl_topic(topic_id) }
  next_page = doc.at_css("#threadPager_Next")
  crawl_topics(next_page.attributes["href"]) if next_page
end

def crawl_topic(topic_id)
  url = "https://social.msdn.microsoft.com/Forums/AZURE/en-US/#{topic_id}?&outputAs=xml"
  doc = Nokogiri::XML get(url)

  doc.xpath("//users/user").each do |user|
    id = user.at("@id").text
    next if @users.has_key?(id) || UserCustomField.exists?(name: "import_id", value: id)

    @users[id] = create_user(
      id: id,
      name: user.at("displayName").text,
      avatar_url: user.at("xlargeImage").text,
    )
  end

  topic_id = nil

  doc.xpath("//messages/message").each do |message|
    id = message.at("@id").text
    next if PostCustomField.exists?(name: "import_id", value: id)

    if topic_id.nil?
      opts = { title: doc.at("//thread/topic").text, views: doc.at("//thread/@views").text.to_i }
    else
      opts = { topic_id: topic_id }
      # TODO: parent_id ?
    end

    opts[:created_at] = message.at("createdOn").text
    opts[:raw] = HtmlToMarkdown.new(message.at("body").text).to_markdown
    opts[:import_mode] = true
    opts[:skip_validations] = true

    user_id = message.at("@authorId").text
    @users[id] ||= UserCustomField.find_by(name: "import_id", value: user_id)&.user
    user = @users[id]

    post = PostCreator.new(user, opts).create!
    post.custom_fields["import_id"] = id
    post.save

    putc "."

    topic_id ||= post.topic_id
  end
end

def create_user(opts = {})
  user = User.new
  user.email = "#{SecureRandom.hex}@foo.bar"
  user.username = UserNameSuggester.suggest(opts[:name])
  user.name = opts[:name]
  user.password = SecureRandom.hex
  user.save!

  user.custom_fields["import_id"] = opts[:id]
  user.active = true
  user.save

  if opts[:avatar_url].present?
    UserAvatar.import_url_for_user(opts[:avatar_url], user) rescue nil
  end

  putc "x"

  user
end

begin
  RateLimiter.disable
  crawl_topics "https://social.msdn.microsoft.com/Forums/AZURE/en-US/home?forum=#{ARGV[0]}"
ensure
  RateLimiter.enable
end
