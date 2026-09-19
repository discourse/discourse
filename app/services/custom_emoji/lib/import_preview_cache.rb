# frozen_string_literal: true

class CustomEmoji::ImportPreviewCache
  TTL = 2.hours
  KEY_NAMESPACE = "emoji_import_preview"

  def initialize(user)
    @user = user
  end

  def store(rows)
    token = SecureRandom.hex
    Discourse.redis.setex(key(token), TTL.to_i, rows.map(&:to_h).to_json)
    token
  end

  def fetch(token)
    payload = Discourse.redis.get(key(token))
    return if payload.blank?
    JSON.parse(payload).map { CustomEmoji::ImportRow.from_h(it) }
  end

  def delete(token)
    Discourse.redis.del(key(token))
  end

  private

  def key(token)
    "#{KEY_NAMESPACE}:#{@user.id}:#{token}"
  end
end
