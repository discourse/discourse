# frozen_string_literal: true

class BackupDownloadResumeToken
  def self.key(user_id, backup_filename)
    filename_digest = Digest::SHA256.hexdigest(backup_filename)
    "backup-download-resume-token:#{user_id}:#{filename_digest}"
  end

  def self.set(user_id, backup_filename, token, ttl:)
    return if ttl.to_i <= 0

    Discourse.redis.setex(key(user_id, backup_filename), ttl.to_i, token)
  end

  def self.compare(user_id, backup_filename, token)
    token == Discourse.redis.get(key(user_id, backup_filename))
  end
end
