# frozen_string_literal: true

module DiscourseAutomation
  class Scriptable
    attr_reader :fields, :automation

    def initialize(automation)
      @automation = automation
      @placeholders = [:site_title]
      @version = 0
      @fields = []
      @triggerables = []
      @script = Proc.new {}

      eval!
    end

    def eval!
      public_send("__scriptable_#{automation.script.underscore}")
      self
    end

    def name
      @automation.script
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

    def field(name, component:, accepts_placeholders: false)
      @fields << {
        name: name,
        component: component,
        accepts_placeholders: accepts_placeholders
      }
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
