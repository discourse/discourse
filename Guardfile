phantom_path = File.expand_path('~/phantomjs/bin/phantomjs')
phantom_path = nil unless File.exists?(phantom_path)

jasmine_options = {:phantomjs_bin => phantom_path, :server_env => :test}

if ENV['JASMINE_URL']
  jasmine_options[:jasmine_url] = ENV['JASMINE_URL']
  jasmine_options[:server] = :none
else
  jasmine_options[:server] = :thin
  jasmine_options[:port] = 8888
  jasmine_options[:server_timeout] = 300
end

guard 'jasmine', jasmine_options do
  watch(%r{spec/javascripts/spec\.js$})         { "spec/javascripts" }
  watch(%r{spec/javascripts/.+_spec\.js$})
  watch(%r{app/assets/javascripts/(.+?)\.js$})  { "spec/javascripts" }
end

# verify that we pass jshint
# see https://github.com/MrOrz/guard-jshint-on-rails
guard 'jshint-on-rails', config_path: 'config/jshint.yml' do
  # watch for changes to application javascript files
  watch(%r{^app/assets/javascripts/.*\.js$})
  watch(%r{^spec/javascripts/.*\.js$})
end

unless ENV["USING_AUTOSPEC"]
  puts "Sam strongly recommends you Run: `bundle exec rake autospec` in favor of guard for specs, set USING_AUTOSPEC in .rvmrc to disable from Guard"
  guard :spork, wait: 120 do
    watch('config/application.rb')
    watch('config/environment.rb')
    watch(%r{^config/environments/.*\.rb$})
    watch(%r{^config/initializers/.*\.rb$})
    watch('Gemfile')
    watch('Gemfile.lock')
    watch('spec/spec_helper.rb') { :rspec }
  end

  guard 'rspec', :focus_on_failed => true, :cli => "--drb" do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/components/#{m[1]}_spec.rb" }
    watch('spec/spec_helper.rb')  { "spec" }

    # Rails example
    watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
    watch(%r{^app/controllers/(.+)_(controller)\.rb$})  { |m| "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb" }
    watch(%r{^spec/support/(.+)\.rb$})                  { "spec" }
    watch('app/controllers/application_controller.rb')  { "spec/controllers" }

    # Capybara request specs
    watch(%r{^app/views/(.+)/.*\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }
  end
end

module ::Guard
  class AutoReload < ::Guard::Guard

    require File.dirname(__FILE__) + '/config/environment'
    def run_on_change(paths)
      paths.map! do |p|
        hash = nil
        fullpath = Rails.root.to_s + "/" + p
        hash = Digest::MD5.hexdigest(File.read(fullpath)) if File.exists? fullpath
        p = p.sub /\.sass\.erb/, ""
        p = p.sub /\.sass/, ""
        p = p.sub /\.scss/, ""
        p = p.sub /^app\/assets\/stylesheets/, "assets"
        {name: p, hash: hash}
      end
      # target dev
      MessageBus::Instance.new.publish "/file-change", paths
    end

    def run_all
    end
  end
end

Thread.new do
  Listen.to('tmp/') do |modified,added,removed|
    modified.each do |m|
      MessageBus::Instance.new.publish "/file-change", ["refresh"] if m =~ /refresh_browser/
    end
  end
end

guard :autoreload do
  watch(/tmp\/refresh_browser/)
  watch(/\.css$/)
  watch(/\.sass$/)
  watch(/\.scss$/)
  watch(/\.sass\.erb$/)
  watch(/\.handlebars$/)
end
