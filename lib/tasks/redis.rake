task 'redis:clean_up' => ['environment'] do
  return unless Rails.configuration.multisite

  dbs = RailsMultisite::ConnectionManagement.all_dbs
  dbs << Discourse::SIDEKIQ_NAMESPACE

  regexp = /((\$(?<message_bus>\w+)$)|(^?(?<namespace>\w+):))/

  cursor = 0
  redis = $redis.without_namespace

  loop do
    cursor, keys = redis.scan(cursor)
    cursor = cursor.to_i

    redis.multi do
      keys.each do |key|
        if match = key.match(regexp)
          db_name = match[:message_bus] || match[:namespace]

          if !dbs.include?(db_name)
            redis.del(key)
          end
        end
      end
    end

    break if cursor == 0
  end
end
