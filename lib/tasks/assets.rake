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
    # monkey patch asset pipeline not to gzip, compress: false is broken
    class ::Sprockets::Asset
      # Save asset to disk.
      def write_to(filename, options = {})
        # Gzip contents if filename has '.gz'
        return if File.extname(filename) == '.gz'

        begin
          FileUtils.mkdir_p File.dirname(filename)

          File.open("#{filename}+", 'wb') do |f|
            f.write to_s
          end

          # Atomic write
          FileUtils.mv("#{filename}+", filename)

          # Set mtime correctly
          File.utime(mtime, mtime, filename)

          nil
        ensure
          # Ensure tmp file gets cleaned up
          FileUtils.rm("#{filename}+") if File.exist?("#{filename}+")
        end
      end


    end

    module ::Sprockets

      class UglifierCompressor

        def evaluate(context, locals, &block)
          # monkey patch cause we do this later, no idea how to cleanly disable
          data
        end

      end
    end
  end

end

task 'assets:precompile:css' => 'environment' do
  puts "Start compiling CSS: #{Time.zone.now}"
  RailsMultisite::ConnectionManagement.each_connection do |db|
    # Heroku precompiles assets before db migration, so tables may not exist.
    # css will get precompiled during first request instead in that case.
    if ActiveRecord::Base.connection.table_exists?(ColorScheme.table_name)
      puts "Compiling css for #{db}"
      [:desktop, :mobile, :desktop_rtl, :mobile_rtl].each do |target|
        puts DiscourseStylesheets.compile(target)
      end
    end
  end
  puts "Done compiling CSS: #{Time.zone.now}"
end

def assets_path
  "#{Rails.root}/public/assets"
end

def compress_node(from,to)
  to_path = "#{assets_path}/#{to}"

  source_map_root = (d=File.dirname(from)) == "." ? "/assets" : "/assets/#{d}"
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
                               screw_ie8: false,
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
  STDERR.puts `gzip -f -c -9 #{path} > #{path}.gz`
end

def compress(from,to)
  if @has_uglifyjs ||= !`which uglifyjs`.empty?
    compress_node(from,to)
  else
    compress_ruby(from,to)
  end
end

task 'assets:precompile' => 'assets:precompile:before' do
  # Run after assets:precompile
  Rake::Task["assets:precompile:css"].invoke

  if $node_uglify
    puts "Compressing Javascript and Generating Source Maps"
    manifest = Sprockets::Manifest.new(assets_path)

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

          # We can specify some files to never minify
          unless to_skip.include?(info['logical_path'])
            FileUtils.mv(path, _path)
            compress(_file,file)
          end

          info["size"] = File.size(path)
          info["mtime"] = File.mtime(path).iso8601
          gzip(path)
        end
    end

    # protected
    manifest.send :save
  end

end
