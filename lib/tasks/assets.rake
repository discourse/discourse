task 'assets:precompile:before' do

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

    def self.cache_compiled(type, data)
      digest = Digest::SHA1.hexdigest(data)
      key = "SPROCKETS_#{type}_#{digest}"
      if compiled = $redis.get(key)
        $redis.expire(key, 1.week)
      else
        compiled = yield
        $redis.setex(key, 1.week, compiled)
      end
      compiled
    end

    class SassCompressor
      def evaluate(context, locals, &block)
        ::Sprockets.cache_compiled("sass", data) do
           # HACK, SASS compiler will degrade to aweful perf with huge files
           # Bypass if larger than 200kb, ensure assets are minified prior
           if context.pathname &&
              context.pathname.to_s =~ /.css$/ &&
              data.length > 200.kilobytes
             puts "Skipped minifying #{context.pathname} cause it is larger than 200KB, minify in source control or avoid large CSS files"
             data
           else
             ::Sass::Engine.new(data, {
                :syntax => :scss,
                :cache => false,
                :read_cache => false,
                :style => :compressed
              }).render
           end
        end
      end
    end

    class UglifierCompressor

      def evaluate(context, locals, &block)
        ::Sprockets.cache_compiled("uglifier", data) do
           Uglifier.new(:comments => :none).compile(data)
        end
      end

    end
  end

end

task 'assets:precompile' => 'assets:precompile:before'

