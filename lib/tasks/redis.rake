# frozen_string_literal: true

task "redis:clean_up" => ["environment"] do
  next unless Rails.configuration.multisite

  dbs = RailsMultisite::ConnectionManagement.all_dbs
  dbs << Discourse::SIDEKIQ_NAMESPACE

  regexp = /((\$(?<message_bus>\w+)$)|(^?(?<namespace>\w+):))/

  cursor = 0
  redis = Discourse.redis.without_namespace

  loop do
    cursor, keys = redis.scan(cursor)
    cursor = cursor.to_i

    redis.multi do |transaction|
      keys.each do |key|
        if match = key.match(regexp)
          db_name = match[:message_bus] || match[:namespace]

          transaction.del(key) if !dbs.include?(db_name)
        end
      end
    end

    break if cursor == 0
  end
end
