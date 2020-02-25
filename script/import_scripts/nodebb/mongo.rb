# frozen_string_literal: true

require 'mongo'

module NodeBB
  class Mongo
    attr_reader :mongo

    ::Mongo::Logger.logger.level = Logger::WARN

    def initialize(params)
      client = ::Mongo::Client.new(params)
      @mongo = client[:objects]
    end

    def groups
      group_keys = mongo.find(_key: "groups:visible:createtime").pluck(:value)

      group_keys.map { |group_key| group(group_key) }
    end

    def group(id)
      group = mongo.find(_key: "group:#{id}").first
      group["createtime"] = timestamp_to_date(group["createtime"])
      group["member_ids"] = mongo.find(_key: "group:#{id}:members").pluck(:value)
      if mongo.find(_key: "group:#{id}:owners").first
        group["owner_ids"] = mongo.find(_key: "group:#{id}:owners").first[:members]
      else
        group["owner_ids"] = []
      end

      group
    end

    def users
      user_keys = mongo.find(_key: "users:joindate").pluck(:value)

      user_keys.map { |user_key| user(user_key) }
    end

    def user(id)
      user = mongo.find(_key: "user:#{id}").first

      user["joindate"] = timestamp_to_date(user["joindate"])
      user["lastonline"] = timestamp_to_date(user["lastonline"])
      user['banned'] = user['banned'].to_s
      user['uid'] = user['uid'].to_s

      user
    end

    def categories
      category_keys = mongo.find(_key: "categories:cid").pluck(:value)

      {}.tap do |categories|
        category_keys.each do |category_key|
          category = mongo.find(_key: "category:#{category_key}").first

          category['parentCid'] = category['parentCid'].to_s
          category['disabled'] = category['disabled'].to_s
          category['cid'] = category['cid'].to_s

          categories[category['cid']] = category
        end
      end
    end

    def topics(offset = 0, page_size = 2000)
      topic_keys = mongo.find(_key: 'topics:tid').skip(offset).limit(page_size).pluck(:value)

      topic_keys.map { |topic_key| topic(topic_key) }
    end

    def topic(id)
      topic = mongo.find(_key: "topic:#{id}").first

      topic["lastposttime"] = timestamp_to_date(topic["lastposttime"])
      topic["timestamp"] = timestamp_to_date(topic["timestamp"])
      topic["mainpost"] = post(topic["mainPid"])
      topic["mainPid"] = topic["mainPid"].to_s
      topic["deleted"] = topic["deleted"].to_s
      topic["pinned"] = topic["pinned"].to_s
      topic["locked"] = topic["locked"].to_s

      topic
    end

    def topic_count
      mongo.find(_key: 'topics:tid').count
    end

    def posts(offset = 0, page_size = 2000)
      post_keys = mongo.find(_key: 'posts:pid').skip(offset).limit(page_size).pluck(:value)

      post_keys.map { |post_key| post(post_key) }
    end

    def post(id)
      post = mongo.find(_key: "post:#{id}").first
      post["timestamp"] = timestamp_to_date(post["timestamp"])
      if post["upvoted_by"] = mongo.find(_key: "pid:#{id}:upvote").first
        post["upvoted_by"] = mongo.find(_key: "pid:#{id}:upvote").first[:members]
      else
        post["upvoted_by"] = []
      end

      post["pid"] = post["pid"].to_s
      post["deleted"] = post["deleted"].to_s

      post
    end

    def post_count
      mongo.find(_key: 'posts:pid').count
    end

    private

    def timestamp_to_date(createtime)
      Time.at(createtime.to_s[0..-6].to_i).utc if createtime
    end
  end
end
