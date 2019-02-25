module Autospec

  class RspecRunner < BaseRunner

    WATCHERS = {}
    def self.watch(pattern, &blk)
      WATCHERS[pattern] = blk
    end
    def watchers
      WATCHERS
    end

    # Discourse specific
    watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/components/#{m[1]}_spec.rb" }

    watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.+)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^spec/support/.+\.rb$})                    { "spec" }
    watch("app/controllers/application_controller.rb")  { "spec/requests" }

    watch(%r{app/controllers/(.+).rb})  { |m| "spec/requests/#{m[1]}_spec.rb" }

    watch(%r{^app/views/(.+)/.+\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }

    watch(%r{^spec/fabricators/.+_fabricator\.rb$})     { "spec" }

    watch(%r{^app/assets/javascripts/pretty-text/.*\.js\.es6$}) { "spec/components/pretty_text_spec.rb" }
    watch(%r{^plugins/.*/discourse-markdown/.*\.js\.es6$}) { "spec/components/pretty_text_spec.rb" }

    watch(%r{^plugins/.*/spec/.*\.rb})
    watch(%r{^(plugins/.*/)plugin\.rb})     { |m| "#{m[1]}spec" }
    watch(%r{^(plugins/.*)/(lib|app)})    { |m| "#{m[1]}/spec/integration" }
    watch(%r{^(plugins/.*)/lib/(.*)\.rb}) { |m| "#{m[1]}/spec/lib/#{m[2]}_spec.rb" }

    RELOADERS = Set.new
    def self.reload(pattern)
      RELOADERS << pattern
    end
    def reloaders
      RELOADERS
    end

    # we are using a simple runner at the moment, whole idea of using a reloader is no longer needed
    watch("spec/rails_helper.rb")
    watch(%r{config/.+\.rb})
    #reload(%r{app/helpers/.+\.rb})

    def failed_specs
      specs = []
      path = './tmp/rspec_result'
      specs = File.readlines(path) if File.exist?(path)
      specs
    end

  end

end
