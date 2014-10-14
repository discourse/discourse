task 'assets:precompile:before' do

  require 'uglifier'

  unless %w{profile production}.include? Rails.env
    raise "rake assets:precompile should only be run in RAILS_ENV=production, you are risking unminified assets"
  end

  # Ensure we ALWAYS do a clean build
  # We use many .erbs that get out of date quickly, especially with plugins
  puts "Purging temp files"
  `rm -fr #{Rails.root}/tmp/cache`

  # in the past we applied a patch that removed asset postfixes, but it is terrible practice
  # leaving very complicated build issues
  # https://github.com/rails/sprockets-rails/issues/49

  # let's make precompile faster using redis magic
  require 'sprockets'
  require 'digest/sha1'

  module ::Sprockets

    def self.redis
      @redis ||=
        (
          redis_url = GlobalSetting.asset_redis_url
          if redis_url.present?
            uri = URI.parse(redis_url)
            options = {}
            options[:password] = uri.password if uri.password.present?
            options[:host] = uri.host
            options[:port] = uri.port || 6379
            Redis.new(options)
          else
            DiscourseRedis.raw_connection
          end
        )
    end

    def self.cache_compiled(type, data)
      # add cache breaker here if uglifier options change
      digest = Digest::SHA1.hexdigest(data) << "v1"
      key = "SPROCKETS_#{type}_#{digest}"
      if compiled = redis.get(key)
        redis.expire(key, 1.week)
      else
        compiled = yield
        redis.setex(key, 1.week, compiled)
      end
      compiled
    end

    class UglifierCompressor

      def evaluate(context, locals, &block)
        ::Sprockets.cache_compiled("uglifier", data) do
           Uglifier.new(:comments => :none,
                        :screw_ie8 => false,
                        :output => {max_line_len: 1024}).compile(data)
        end
      end

    end
  end

end

task 'assets:precompile:css' => 'environment' do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    # Heroku precompiles assets before db migration, so tables may not exist.
    # css will get precompiled during first request instead in that case.
    if ActiveRecord::Base.connection.table_exists?(ColorScheme.table_name)
      puts "Compiling css for #{db}"
      [:desktop, :mobile].each do |target|
        puts DiscourseStylesheets.compile(target, force: true)
      end
    end
  end
end

task 'assets:precompile' => 'assets:precompile:before' do
  # Run after assets:precompile
  Rake::Task["assets:precompile:css"].invoke
end
