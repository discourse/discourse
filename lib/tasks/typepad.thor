class Typepad < Thor
  desc "import", "Imports posts from a Disqus XML export"
  method_option :file, aliases: '-f', required: true, desc: "The typepad file to import"
  method_option :dry_run, required: false, desc: "Just output what will be imported rather than doing it"
  method_option :post_as, aliases: '-p', required: true, desc: "The Discourse username to post as"


  def import
    require './config/environment'

    email_blacklist = SiteSetting.email_domains_blacklist

    user = User.where(username_lower: options[:post_as].downcase).first
    if user.nil?
      puts "No user found named: '#{options[:post_as]}'"
      exit 1
    end

    unless File.exist?(options[:file])
      puts "File '#{options[:file]}' not found"
      exit 1
    end

    inside_block = true
    entry = ""

    n = 0
    entries = []
    File.open(options[:file]).each_line do |l|
      l = l.scrub

      if l =~ /^--------$/
        entries << process_entry(entry)
        entry = ""
      else
        entry << l
      end
      break if entries.size > 5
    end

    entries.compact!

    RateLimiter.disable

    SiteSetting.email_domains_blacklist = ""

    puts "import it"
    puts entries.size
    entries.each do |entry|
      post = TopicEmbed.import(user, entry[:unique_url], entry[:title], entry[:body])
      if post.present?
        entry[:comments].each do |c|
          username = c[:author]
          if c[:email].present?
            email = c[:email]
            post_user = User.where(email: email).first
            if post_user.blank?
              post_user = User.create!(email: email, username: UserNameSuggester.suggest(username))
            end
          else
            suggested = UserNameSuggester.suggest(username)
            post_user = User.where(username: suggested)
            if post_user.blank?
              post_user = User.create!(email: "#{suggested}@no-email-found.com", username: UserNameSuggester.suggest(username))
            end
          end

          attrs = {
            topic_id: post.topic_id,
            raw: c[:body],
            cooked: c[:body],
            created_at: Time.now
          }
          post = PostCreator.new(post_user, attrs).create
        end
      end
    end

  ensure
    RateLimiter.enable
    SiteSetting.email_domains_blacklist = email_blacklist
  end

  private

  def clean_type!(type)
    type.downcase!
    type.gsub!(/ /, '_')
    type
  end

  def parse_meta_data(section)
    result = {}
    section.split(/\n/).each do |l|
      if l =~ /^([^:]+)\: (.*)$/
        key, value = Regexp.last_match[1], Regexp.last_match[2]
        clean_type!(key)
        value.strip!
        result[key.to_sym] = value
      else
        result[:body] ||= ""
        result[:body] << l
      end
    end
    result
  end

  def parse_section(section)
    section.strip!
    if section =~ /^([^:]+):/
      type = clean_type!(Regexp.last_match[1])
      value = section.split("\n")[1..-1].join("\n")
      value.strip!
      return [type.to_sym, value] if value.present?
    end
  end

  def parse_comment(section)
    return parse_meta_data(section)
  end

  def process_entry(entry)
    sections = entry.split(/-----/)
    entry = parse_meta_data(sections[0]).slice(:date, :title, :unique_url)
    entry[:comments] = []
    sections[1..-1].each do |s|
      type, value = parse_section(s)
      case type
      when :body
        entry[type] = value
      when :comment
        comment = parse_comment(value).slice(:author, :email, :url, :body, :date)
        entry[:comments] << comment if comment[:body].present?
      end
    end

    entry[:title] && entry[:body] ? entry : nil
  end
end


