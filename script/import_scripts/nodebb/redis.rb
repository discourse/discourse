require 'redis'

module NodeBB
  class Redis
    attr_reader :redis

    def initialize(params)
      @redis = ::Redis.new(params)
    end

    def groups
      group_keys = redis.zrange('groups:visible:createtime', 0, -1)

      group_keys.map { |group_key| group(group_key) }
    end

    def group(id)
      group = redis.hgetall("group:#{id}")
      group["createtime"] = timestamp_to_date(group["createtime"])
      group["member_ids"] = redis.zrange("group:#{id}:members", 0, -1)
      group["owner_ids"] = redis.smembers("group:#{id}:owners")

      group
    end

    def users
      user_keys = redis.zrange('users:joindate', 0, -1)

      user_keys.map { |user_key| user(user_key) }
    end

    def user(id)
      user = redis.hgetall("user:#{id}")

      user["joindate"] = timestamp_to_date(user["joindate"])
      user["lastonline"] = timestamp_to_date(user["lastonline"])

      user
    end

    def categories
      category_keys = redis.zrange('categories:cid', 0, -1)

      {}.tap do |categories|
        category_keys.each do |category_key|
          category = redis.hgetall("category:#{category_key}")

          categories[category['cid']] = category
        end
      end
    end

    def topics(offset = 0, page_size = 2000)
      # redis get keys inclusive
      # so we move the offset a bit to continue in the next item
      offset = offset + 1 unless offset == 0
      from = offset
      to = page_size + offset

      topic_keys = redis.zrange('topics:tid', from, to)

      topic_keys.map { |topic_key| topic(topic_key) }
    end

    def topic(id)
      topic = redis.hgetall("topic:#{id}")

      topic["lastposttime"] = timestamp_to_date(topic["lastposttime"])
      topic["timestamp"] = timestamp_to_date(topic["timestamp"])
      topic["mainpost"] = post(topic["mainPid"])

      topic
    end

    def topic_count
      redis.zcard('topics:tid')
    end

    def posts(offset = 0, page_size = 2000)
      # redis get keys inclusive
      # so we move the offset a bit to continue in the next item
      offset = offset + 1 unless offset == 0
      from = offset
      to = page_size + offset

      post_keys = redis.zrange('posts:pid', from, to)

      post_keys.map { |post_key| post(post_key) }
    end

    def post(id)
      post = redis.hgetall("post:#{id}")
      post["timestamp"] = timestamp_to_date(post["timestamp"])
      post["upvoted_by"] = redis.smembers("pid:#{id}:upvote")

      post
    end

    def post_count
      redis.zcard('posts:pid')
    end

    private

    def timestamp_to_date(createtime)
      Time.at(createtime[0..-4].to_i).utc if createtime
    end
  end
end
