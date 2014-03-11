task 'assets:precompile:before' do

  unless %w{profile production staging}.include? Rails.env
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
    class UglifierCompressor
      def evaluate(context, locals, &block)

        digest = Digest::SHA1.hexdigest(data)
        key = "SPROCKETS_#{digest}"

        if compiled = $redis.get(key)
          $redis.expire(key, 1.week)
        else
          compiled = Uglifier.new(:comments => :none).compile(data)
          $redis.setex(key, 1.week, compiled)
        end
        compiled
      end
    end
  end

end

task 'assets:precompile' => 'assets:precompile:before'

