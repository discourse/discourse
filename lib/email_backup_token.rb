# frozen_string_literal: true

class EmailBackupToken
  class << self
    def key(user_id)
      "email-backup-token:#{user_id}"
    end

    def generate
      SecureRandom.hex
    end

    def set(user_id)
      token = generate
      Discourse.redis.setex key(user_id), 1.day.to_i, token
      token
    end

    def get(user_id)
      Discourse.redis.get key(user_id)
    end

    def del(user_id)
      Discourse.redis.del key(user_id)
    end

    def compare(user_id, token)
      token == get(user_id)
    end
  end
end
