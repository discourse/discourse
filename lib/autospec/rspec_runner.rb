module Autospec

  class RspecRunner < BaseRunner

    WATCHERS = {}
    def self.watch(pattern, &blk); WATCHERS[pattern] = blk; end
    def watchers; WATCHERS; end

    # Discourse specific
    watch(%r{^lib/(.+)\.rb$})                           { |m| "spec/components/#{m[1]}_spec.rb" }

    watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
    watch(%r{^app/(.+)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^spec/support/.+\.rb$})                    { "spec" }
    watch("app/controllers/application_controller.rb")  { "spec/controllers" }

    watch(%r{^app/views/(.+)/.+\.(erb|haml)$})          { |m| "spec/requests/#{m[1]}_spec.rb" }

    watch(%r{^spec/fabricators/.+_fabricator\.rb$})     { "spec" }

    RELOADERS = Set.new
    def self.reload(pattern); RELOADERS << pattern; end
    def reloaders; RELOADERS; end

    # We need to reload the whole app when changing any of these files
    reload("spec/rails_helper.rb")
    reload(%r{config/.+\.rb})
    reload(%r{app/helpers/.+\.rb})

    def failed_specs
      specs = []
      path = './tmp/rspec_result'
      specs = File.readlines(path) if File.exist?(path)
      specs
    end

  end

end
