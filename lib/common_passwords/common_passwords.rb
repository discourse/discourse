# frozen_string_literal: true

# CommonPasswords will check a given password against a list of the most commonly used passwords.
# The list comes from https://github.com/danielmiessler/SecLists/tree/master/Passwords
# specifically the list of 10 million passwords, top 100k, filtered by length
#
# The list is stored in Redis at a key that is shared by all sites in a multisite config.
#
# If the password file is changed, you need to add a migration that deletes the list from redis
# so it gets re-populated:
#
#   Discourse.redis.without_namespace.del CommonPasswords::LIST_KEY

class CommonPasswords

  PASSWORD_FILE = File.join(Rails.root, 'lib', 'common_passwords', '10-char-common-passwords.txt')
  LIST_KEY = 'discourse-common-passwords'

  @mutex = Mutex.new

  def self.common_password?(password)
    return false unless password.present?
    password_list.include?(password)
  end

  private

  class RedisPasswordList
    def include?(password)
      CommonPasswords.redis.sismember CommonPasswords::LIST_KEY, password
    end
  end

  def self.password_list
    @mutex.synchronize do
      load_passwords unless redis.scard(LIST_KEY) > 0
    end
    RedisPasswordList.new
  end

  def self.redis
    Discourse.redis.without_namespace
  end

  def self.load_passwords
    passwords = File.readlines(PASSWORD_FILE)
    passwords.map!(&:chomp).each do |pwd|
      # slower, but a tad more compatible
      redis.sadd LIST_KEY, pwd
    end
  rescue Errno::ENOENT
    # tolerate this so we don't block signups
    Rails.logger.error "Common passwords file #{PASSWORD_FILE} is not found! Common password checking is skipped."
  end

end
