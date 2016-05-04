task 'assets:precompile:before' do

  require 'uglifier'

  unless %w{profile production}.include? Rails.env
    raise "rake assets:precompile should only be run in RAILS_ENV=production, you are risking unminified assets"
  end

  # Ensure we ALWAYS do a clean build
  # We use many .erbs that get out of date quickly, especially with plugins
  puts "Purging temp files"
  `rm -fr #{Rails.root}/tmp/cache`

  if Rails.configuration.assets.js_compressor == :uglifier && !`which uglifyjs`.empty? && !ENV['SKIP_NODE_UGLIFY']
    $node_uglify = true
  end

  puts "Bundling assets"

  # in the past we applied a patch that removed asset postfixes, but it is terrible practice
  # leaving very complicated build issues
  # https://github.com/rails/sprockets-rails/issues/49

  require 'sprockets'
  require 'digest/sha1'

  # Needed for proper source maps with a CDN
  load "#{Rails.root}/lib/global_path.rb"
  include GlobalPath

  if $node_uglify
    Rails.configuration.assets.js_compressor = nil

    module ::Sprockets
      # TODO: https://github.com/rails/sprockets-rails/pull/342
      # Rails.configuration.assets.gzip = false
      class Base
        def skip_gzip?
          true
        end
      end
    end
  end

end

task 'assets:precompile:css' => 'environment' do
  if ENV["DONT_PRECOMPILE_CSS"] == "1"
    STDERR.puts "Skipping CSS precompilation, ensure CSS lives in a shared directory across hosts"
  else
    STDERR.puts "Start compiling CSS: #{Time.zone.now}"

    RailsMultisite::ConnectionManagement.each_connection do |db|
      # Heroku precompiles assets before db migration, so tables may not exist.
      # css will get precompiled during first request instead in that case.

      if ActiveRecord::Base.connection.table_exists?(ColorScheme.table_name)
        STDERR.puts "Compiling css for #{db}"
        [:desktop, :mobile, :desktop_rtl, :mobile_rtl].each do |target|
          STDERR.puts "target: #{target} #{DiscourseStylesheets.compile(target)}"
        end
      end
    end

    STDERR.puts "Done compiling CSS: #{Time.zone.now}"
  end
end

def assets_path
  "#{Rails.root}/public/assets"
end

def compress_node(from,to)
  to_path = "#{assets_path}/#{to}"
  assets = cdn_relative_path("/assets")
  source_map_root = assets + ((d=File.dirname(from)) == "." ? "" : "/#{d}")
  source_map_url = cdn_path "/assets/#{to}.map"

  cmd = "uglifyjs '#{assets_path}/#{from}' -p relative -c -m -o '#{to_path}' --source-map-root '#{source_map_root}' --source-map '#{assets_path}/#{to}.map' --source-map-url '#{source_map_url}'"

  STDERR.puts cmd
  result = `#{cmd} 2>&1`
  unless $?.success?
    STDERR.puts result
    exit 1
  end

  result
end

def compress_ruby(from,to)
  data = File.read("#{assets_path}/#{from}")

  uglified, map = Uglifier.new(comments: :none,
                               screw_ie8: true,
                               source_filename: File.basename(from),
                               output_filename: File.basename(to)
                              )
                          .compile_with_map(data)
  dest = "#{assets_path}/#{to}"

  File.write(dest, uglified << "\n//# sourceMappingURL=#{cdn_path "/assets/#{to}.map"}")
  File.write(dest + ".map", map)
end

def gzip(path)
  STDERR.puts "gzip #{path}"
  STDERR.puts `gzip -f -c -7 #{path} > #{path}.gz`
end

def compress(from,to)
  if @has_uglifyjs ||= !`which uglifyjs`.empty?
    compress_node(from,to)
  else
    compress_ruby(from,to)
  end
end

def concurrent?
  if ENV["CONCURRENT"] == "1"
    concurrent_compressors = []
    yield(Proc.new { |&block| concurrent_compressors << Concurrent::Future.execute { block.call } })
    concurrent_compressors.each(&:wait!)
  else
    yield(Proc.new { |&block| block.call })
  end
end

task 'assets:precompile' => 'assets:precompile:before' do
  # Run after assets:precompile
  Rake::Task["assets:precompile:css"].invoke

  if $node_uglify
    puts "Compressing Javascript and Generating Source Maps"
    manifest = Sprockets::Manifest.new(assets_path)

    concurrent? do |proc|
      to_skip = Rails.configuration.assets.skip_minification || []
      manifest.files
              .select{|k,v| k =~ /\.js$/}
              .each do |file, info|

          path = "#{assets_path}/#{file}"
          _file = (d = File.dirname(file)) == "." ? "_#{file}" : "#{d}/_#{File.basename(file)}"
          _path = "#{assets_path}/#{_file}"

          if File.exists?(_path)
            STDERR.puts "Skipping: #{file} already compressed"
          else
            STDERR.puts "Compressing: #{file}"

            proc.call do
              # We can specify some files to never minify
              unless (ENV["DONT_MINIFY"] == "1") || to_skip.include?(info['logical_path'])
                FileUtils.mv(path, _path)
                compress(_file,file)
              end

              info["size"] = File.size(path)
              info["mtime"] = File.mtime(path).iso8601
              gzip(path)
            end
          end
      end
    end

    # protected
    manifest.send :save
  end

end
