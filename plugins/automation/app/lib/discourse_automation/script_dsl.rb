module DiscourseAutomation
  module ScriptDSL
    attr_reader :script_fields
    attr_reader :script_block
    attr_reader :script_placeholders
    attr_reader :script_version

    def placeholders(placeholders)
      @script_placeholders = placeholders
    end

    def version(version)
      @script_version = version
    end

    def script(&block)
      @script_block = block
    end

    def field(name, component:, placeholders: false)
      @script_fields ||= []
      @script_fields << { name: name, component: component, placeholders: placeholders }
    end

    def utils
      Utils
    end

    module Utils
      def self.apply_placeholders(input, map)
        map.each do |key, value|
          input = input.gsub("%%#{key}%%", value)
        end

        input
      end

      def self.send_pm(options, sender = Discourse.system_user)
        options = options.merge(archetype: Archetype.private_message)

        post_created = false

        if defined?(EncryptedPostCreator)
          post_created = EncryptedPostCreator.new(sender, options).create
        end

        if !post_created
          PostCreator.new(sender, options).create
        end
      end
    end
  end
end
