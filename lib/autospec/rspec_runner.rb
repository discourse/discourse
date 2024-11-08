# frozen_string_literal: true

module Autospec
  class RspecRunner < BaseRunner
    WATCHERS = {}.freeze
    def self.watch(pattern, &blk)
      WATCHERS[pattern] = blk
    end

    def watchers
      WATCHERS
    end

    # Discourse specific
    watch(%r{\Alib/(.+)\.rb\z}) { |m| "spec/components/#{m[1]}_spec.rb" }

    watch(%r{\Aapp/(.+)\.rb\z}) { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{\Aapp/(.+)(\.erb|\.haml)\z}) { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
    watch(%r{\Aspec/.+_spec\.rb\z})
    watch(%r{\Aspec/support/.+\.rb\z}) { "spec" }
    watch("app/controllers/application_controller.rb") { "spec/requests" }

    watch(%r{app/controllers/(.+).rb}) { |m| "spec/requests/#{m[1]}_spec.rb" }

    watch(%r{\Aapp/views/(.+)/.+\.(erb|haml)\z}) { |m| "spec/requests/#{m[1]}_spec.rb" }

    watch(%r{\Aspec/fabricators/.+_fabricator\.rb\z}) { "spec" }

    watch(%r{\Aapp/assets/javascripts/pretty-text/.*\.js\.es6\z}) do
      "spec/components/pretty_text_spec.rb"
    end
    watch(%r{\Aplugins/.*/discourse-markdown/.*\.js\.es6\z}) do
      "spec/components/pretty_text_spec.rb"
    end

    watch(%r{\Aplugins/.*/spec/.*\.rb})
    watch(%r{\A(plugins/.*/)plugin\.rb}) { |m| "#{m[1]}spec" }
    watch(%r{\A(plugins/.*)/(lib|app)}) { |m| "#{m[1]}/spec/integration" }
    watch(%r{\A(plugins/.*)/lib/(.*)\.rb}) { |m| "#{m[1]}/spec/lib/#{m[2]}_spec.rb" }

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
      path = "./tmp/rspec_result"
      specs = File.readlines(path) if File.exist?(path)
      specs
    end
  end
end
