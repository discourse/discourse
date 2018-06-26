require 'json'
require 'cgi'
require 'time'
require_relative 'create_title.rb'

class SocialcastMessage

  DEFAULT_CATEGORY = "Socialcast Import"
  DEFAULT_TAG = "socialcast-import"
  TAGS_AND_CATEGORIES = {
    "somegroupname" => {
      category: "Apple Stems",
      tags: ["waxy", "tough"]
    },
    "someothergroupname" => {
      category: "Orange Peels",
      tags: ["oily"]
    }
   }

  def initialize(message_json)
    @parsed_json = JSON.parse message_json
  end

  def topic
    topic = {}
    topic[:id] = @parsed_json['id']
    topic[:author_id] = @parsed_json['user']['id']
    topic[:title] = title
    topic[:raw] = @parsed_json['body']
    topic[:created_at] = Time.parse @parsed_json['created_at']
    topic[:tags] = tags
    topic[:category] = category
    topic
  end

  def title
    CreateTitle.from_body @parsed_json['body']
  end

  def tags
    tags = []
    if group
      if TAGS_AND_CATEGORIES[group]
        tags = TAGS_AND_CATEGORIES[group][:tags]
      else
        tags << group
      end
    end
    tags << DEFAULT_TAG
    tags
  end

  def category
    category = DEFAULT_CATEGORY
    if group && TAGS_AND_CATEGORIES[group]
      category = TAGS_AND_CATEGORIES[group][:category]
    end
    category
  end

  def group
    @parsed_json['group']['groupname'].downcase if @parsed_json['group'] && @parsed_json['group']['groupname']
  end

  def url
    @parsed_json['url']
  end

  def message_type
    @parsed_json['message_type']
  end

  def replies
    posts = []
    comments = @parsed_json['comments']
    comments.each do |comment|
      posts << post_from_comment(comment)
    end
    posts
  end

  def post_from_comment(comment)
    post = {}
    post[:id] = comment['id']
    post[:author_id] = comment['user']['id']
    post[:raw] = comment['text']
    post[:created_at] = Time.parse comment['created_at']
    post
  end

  private

  def unescape(html)
    return nil unless html
    CGI.unescapeHTML html
  end
end
