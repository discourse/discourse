# frozen_string_literal: true

module DiscourseAutomation
  class Scriptable
    attr_reader :fields, :name, :not_found

    def initialize(name)
      @name = name
      @version = 0
      @fields = []
      @placeholders = [:site_title]
      @triggerables = []
      @script = proc {}
      @not_found = false

      eval! if @name
    end

    def eval!
      begin
        public_send("__scriptable_#{name.underscore}")
      rescue NoMethodError
        @not_found = true
      end

      self
    end

    def placeholders
      @placeholders.uniq.compact
    end

    def placeholder(placeholder)
      @placeholders << placeholder
    end

    def version(*args)
      if args.present?
        @version, = args
      else
        @version
      end
    end

    def triggerables(*args)
      if args.present?
        @triggerables, = args
      else
        @triggerables
      end
    end

    def script(&block)
      if block_given?
        @script = block
      else
        @script
      end
    end

    def field(name, component:, extra: {}, accepts_placeholders: false)
      @fields << {
        name: name,
        component: component,
        accepts_placeholders: accepts_placeholders,
        extra: extra
      }
    end

    def components
      fields.map { |f| f[:component] }.uniq
    end

    def utils
      Utils
    end

    module Utils
      def self.apply_placeholders(input, map)
        input = input.dup
        map[:site_title] = SiteSetting.title

        map.each do |key, value|
          input.gsub!("%%#{key.upcase}%%", value)
        end

        input
      end

      def self.send_pm(pm, sender: Discourse.system_user.username, delay: nil, automation_id: nil, encrypt: true)
        pm = pm.symbolize_keys

        if delay && automation_id
          pm[:execute_at] = delay.to_i.minutes.from_now
          pm[:sender] = sender
          pm[:automation_id] = automation_id
          DiscourseAutomation::PendingPm.create!(pm)
        else
          if sender = User.find_by(username: sender)
            post_created = false
            pm = pm.merge(archetype: Archetype.private_message)

            if encrypt && defined?(EncryptedPostCreator)
              pm[:target_usernames] = (pm[:target_usernames] || []).join(',')
              post_created = EncryptedPostCreator.new(sender, pm).create
            end

            if !post_created
              PostCreator.new(sender, pm).create
            end
          else
            Rails.logger.warn "[discourse-automation] Couldn’t send PM to user with username: `#{sender}`."
          end
        end
      end
    end

    def self.add(identifier, &block)
      @@all_scriptables = nil
      define_method("__scriptable_#{identifier}", &block)
    end

    def self.all
      @@all_scriptables ||= DiscourseAutomation::Scriptable
        .instance_methods(false)
        .grep(/^__scriptable_/)
    end
  end
end
