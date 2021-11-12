# frozen_string_literal: true

module DiscourseAutomation
  class Scriptable
    attr_reader :fields, :name, :not_found, :forced_triggerable

    @@plugin_triggerables ||= {}

    class << self
      def add_plugin_triggerable(triggerable, scriptable)
        @@plugin_triggerables[scriptable.to_sym] ||= []
        @@plugin_triggerables[scriptable.to_sym] << triggerable.to_sym
      end

      def plugin_triggerables
        @@plugin_triggerables
      end
    end

    def initialize(name)
      @name = name
      @version = 0
      @fields = []
      @placeholders = [:site_title]
      @triggerables = (@@plugin_triggerables[name&.to_sym] || [])
      @script = proc {}
      @not_found = false
      @forced_triggerable = nil

      eval! if @name
    end

    def id
      'script'
    end

    def scriptable?
      true
    end

    def triggerable?
      false
    end

    def eval!
      begin
        public_send("__scriptable_#{name.underscore}")
      rescue NoMethodError
        @not_found = true
      end

      self
    end

    def triggerable!(*args)
      if args.present?
        @forced_triggerable = { triggerable: args[0], state: args[1] }
      else
        @forced_triggerable
      end
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

    def permits_trigger?(triggerable)
      Array(triggerables.map(&:to_s)).include?(triggerable.to_s)
    end

    def triggerables(*args)
      if args.present?
        @triggerables.push(*args[0])
      else
        forced_triggerable ? [forced_triggerable[:triggerable]] : @triggerables
      end
    end

    def script(&block)
      if block_given?
        @script = block
      else
        @script
      end
    end

    def field(name, component:, **options)
      @fields << {
        name: name,
        component: component,
        extra: {},
        accepts_placeholders: false,
        triggerable: nil,
        required: false
      }.merge(options || {})
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
      @all_scriptables = nil
      define_method("__scriptable_#{identifier}", &block)
    end

    def self.all
      @all_scriptables ||= DiscourseAutomation::Scriptable
        .instance_methods(false)
        .grep(/^__scriptable_/)
    end
  end
end
