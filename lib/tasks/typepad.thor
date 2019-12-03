# frozen_string_literal: true

require 'open-uri'

class Typepad < Thor

  desc "import", "Imports posts from a Disqus XML export"
  method_option :file, aliases: '-f', required: true, desc: "The typepad file to import"
  method_option :post_as, aliases: '-p', required: true, desc: "The Discourse username to post as"
  method_option :google_api, aliases: '-g', required: false, desc: "The google plus API key to use to fetch usernames"

  def import
    require './config/environment'

    backup_settings = {}
    %w(email_domains_blacklist).each do |s|
      backup_settings[s] = SiteSetting.get(s)
    end

    user = User.where(username_lower: options[:post_as].downcase).first
    if user.nil?
      puts "No user found named: '#{options[:post_as]}'"
      exit 1
    end

    unless File.exist?(options[:file])
      puts "File '#{options[:file]}' not found"
      exit 1
    end

    input = ""

    entries = []
    File.open(options[:file]).each_line do |l|
      l = l.scrub

      if l =~ /^--------$/
        parsed_entry = process_entry(input)
        if parsed_entry
          puts "Parsed #{parsed_entry[:title]}"
          entries << parsed_entry
        end
        input = ""
      else
        input << l
      end
    end

    entries.each_with_index do |e, i|
      if e[:title] =~ /Head/
        puts "#{i}: #{e[:title]}"
      end
    end

    RateLimiter.disable
    SiteSetting.email_domains_blacklist = ""

    puts "Importing #{entries.size} entries"

    entries.each_with_index do |entry, idx|
      puts "Importing (#{idx + 1}/#{entries.size})"
      next if entry[:body].blank?

      puts entry[:unique_url]
      post = TopicEmbed.import(user, entry[:unique_url], entry[:title], entry[:body])
      if post.present?
        post.update_column(:created_at, entry[:date])
        post.topic.update_column(:created_at, entry[:date])
        post.topic.update_column(:bumped_at, entry[:date])
        entry[:comments].each do |c|
          username = c[:author]

          if c[:email].present? && c[:email] != "none@unknown.com"
            email = c[:email]
            post_user = User.where(email: email).first
            if post_user.blank?
              post_user = User.create!(name: c[:name], email: email, username: UserNameSuggester.suggest(username))
            end
          else
            post_user = User.where(username: username).first
            if post_user.blank?
              suggested = UserNameSuggester.suggest(username)
              post_user = User.create!(name: c[:name], email: "#{suggested}@no-email-found.com", username: suggested)
            end
          end

          attrs = {
            topic_id: post.topic_id,
            raw: c[:body],
            cooked: c[:body],
            created_at: c[:date],
            skip_validations: true
          }
          begin
            post = PostCreator.new(post_user, attrs).create
            puts post.errors.inspect if post.id.blank?
          rescue => ex
            puts "Error creating post: #{ex.inspect}"
          end
        end
      end
    end

  ensure
    RateLimiter.enable
    backup_settings.each do |s, v|
      SiteSetting.set(s, v)
    end
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
      if l =~ /^([A-Z\ ]+)\: (.*)$/
        key, value = Regexp.last_match[1], Regexp.last_match[2]
        clean_type!(key)
        value.strip!
        result[key.to_sym] = value
      else
        result[:body] ||= ""
        result[:body] << l << "\n"
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
    parse_meta_data(section)
  end

  def process_entry(entry)
    sections = entry.split(/-----/)
    entry = parse_meta_data(sections[0]).slice(:date, :title, :unique_url)
    entry[:comments] = []
    entry[:date] = entry[:date] ? DateTime.strptime(entry[:date], "%m/%d/%Y") : Time.now
    sections[1..-1].each do |s|
      type, value = parse_section(s)
      case type
      when :body
        entry[type] = value
      when :comment
        comment = parse_comment(value).slice(:author, :email, :url, :body, :date)

        if options[:google_api] && comment[:author] =~ /plus.google.com\/(\d+)/
          gplus_id = Regexp.last_match[1]
          from_redis = Discourse.redis.get("gplus:#{gplus_id}")
          if from_redis.blank?
            json = ::JSON.parse(open("https://www.googleapis.com/plus/v1/people/#{gplus_id}?key=#{options[:google_api]}").read)
            from_redis = json['displayName']
            Discourse.redis.set("gplus:#{gplus_id}", from_redis)
          end
          comment[:author] = from_redis
        end

        if comment[:author] =~ /([^\.]+)\.wordpress\.com/
          comment[:author] = Regexp.last_match[1]
        end

        if comment[:author] =~ /([^\.]+)\.blogspot\.com/
          comment[:author] = Regexp.last_match[1]
        end

        if comment[:author] =~ /twitter.com\/([a-zA-Z0-9]+)/
          comment[:author] = Regexp.last_match[1]
        end

        if comment[:author] =~ /www.facebook.com\/profile.php\?id=(\d+)/
          fb_id = Regexp.last_match[1]
          from_redis = Discourse.redis.get("fb:#{fb_id}")
          if from_redis.blank?
            json = ::JSON.parse(open("http://graph.facebook.com/#{fb_id}").read)
            from_redis = json['username']
            Discourse.redis.set("fb:#{fb_id}", from_redis)
          end
          comment[:author] = from_redis
        end

        comment[:name] = comment[:author]
        if comment[:author]
          comment[:author].gsub!(/^[_\.]+/, '')
          comment[:author].gsub!(/[_\.]+$/, '')

          if comment[:author].size < 12
            comment[:author].gsub!(/ /, '_')
          else
            segments = []
            current = ""

            last_upper = nil
            comment[:author].each_char do |c|
              is_upper = /[[:upper:]]/.match(c)

              if (current.size > 1 && is_upper != last_upper)
                segments << current
                current = ""
              end
              last_upper = is_upper

              if c == " " || c == "." || c == "_" || c == "-"
                segments << current
                current = ""
              else
                current << c
              end
            end
            segments.delete_if { |segment| segment.nil? || segment.size < 2 }
            segments << current

            comment[:author] = segments[0]
            if segments.size > 1 && segments[1][0] =~ /[a-zA-Z]/
              comment[:author] << segments[1][0]
            end
          end
        end

        comment[:author] = "commenter" if comment[:author].blank?
        comment[:author] = "codinghorror" if comment[:author] == "Jeff Atwood" || comment[:author] == "JeffAtwood" || comment[:author] == "Jeff_Atwood"

        comment[:date] = comment[:date] ? DateTime.strptime(comment[:date], "%m/%d/%Y") : Time.now
        entry[:comments] << comment if comment[:body].present?
      end
    end

    entry[:title] && entry[:body] ? entry : nil
  end

end
