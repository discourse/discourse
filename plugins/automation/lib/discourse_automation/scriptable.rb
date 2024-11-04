# frozen_string_literal: true

module DiscourseAutomation
  class Scriptable
    attr_reader :fields,
                :name,
                :not_found,
                :forced_triggerable,
                :background,
                :automation,
                :placeholders

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

    def initialize(name, automation = nil)
      @name = name
      @version = 0
      @fields = []
      @placeholders = []
      @triggerables = (@@plugin_triggerables[name&.to_sym] || [])
      @script = proc {}
      @on_reset = proc {}
      @not_found = false
      @forced_triggerable = nil
      @background = false
      @automation = automation

      eval! if @name
    end

    def run_in_background
      @background = true
    end

    def id
      "script"
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

    def placeholder(name = nil, triggerable: nil, &block)
      if block_given?
        result = yield(@automation.serialized_fields, @automation)
        Array(result).each do |name|
          @placeholders << { name: name.to_sym, triggerable: triggerable&.to_sym }
        end
      elsif name
        @placeholders << { name: name.to_sym, triggerable: triggerable&.to_sym }
      end
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

    def on_reset(&block)
      if block_given?
        @on_reset_block = block
      else
        @on_reset_block
      end
    end

    def field(name, component:, **options)
      @fields << {
        name: name,
        component: component,
        extra: {
        },
        accepts_placeholders: false,
        accepted_contexts: [],
        triggerable: nil,
        required: false,
      }.merge(options || {})
    end

    def components
      fields.map { |f| f[:component] }.uniq
    end

    def utils
      Utils
    end

    module Utils
      def self.fetch_report(name, args = {})
        report = Report.find(name, args)

        return if !report

        return if !report.modes.include?(:table)

        ordered_columns = report.labels.map { |l| l[:property] }

        table = +"\n"
        table << "|" + report.labels.map { |l| l[:title] }.join("|") + "|\n"
        table << "|" + report.labels.count.times.map { "-" }.join("|") + "|\n"
        if report.data.count > 0
          report.data.each do |data|
            table << "|#{ordered_columns.map { |col| data[col] }.join("|")}|\n"
          end
        else
          table << "|" + report.labels.count.times.map { " " }.join("|") + "|\n"
        end
        table
      end

      def self.apply_placeholders(input, map = {})
        input = input.dup
        map[:site_title] = SiteSetting.title

        input = apply_report_placeholder(input)

        map.each { |key, value| input = input.gsub("%%#{key.upcase}%%", value.to_s) }

        input = Mustache.render(input, map).to_s
      end

      REPORT_REGEX = /%%REPORT=(.*?)%%/
      def self.apply_report_placeholder(input = "")
        input.gsub(REPORT_REGEX) do |pattern|
          match = pattern.match(REPORT_REGEX)
          if match
            params = match[1].match(/^(.*?)(?:\s(.*))?$/)

            args = { filters: {} }
            if params[2]
              params[2]
                .split(" ")
                .each do |param|
                  key, value = param.split("=")
                  if %w[start_date end_date].include?(key)
                    args[key.to_sym] = begin
                      Date.parse(value)
                    rescue StandardError
                      nil
                    end
                  else
                    args[:filters][key.to_sym] = value
                  end
                end
            end

            fetch_report(params[1].downcase, args) || ""
          end
        end
      end

      def self.build_quote(post)
        return "" if post.nil? || post.raw.nil?

        full_name = post.user.name
        name =
          if SiteSetting.display_name_on_posts && !SiteSetting.prioritize_username_in_ux
            full_name || post.username
          else
            post.username
          end

        params = [name, "post:#{post.post_number}", "topic:#{post.topic_id}"]

        if SiteSetting.display_name_on_posts && !SiteSetting.prioritize_username_in_ux && full_name
          params.push("username:#{post.username}")
        end

        "[quote=#{params.join(", ")}]\n#{post.raw.strip}\n[/quote]\n\n"
      end

      def self.send_pm(
        pm,
        sender: Discourse.system_user.username,
        delay: nil,
        automation_id: nil,
        prefers_encrypt: true
      )
        pm = pm.symbolize_keys
        prefers_encrypt = prefers_encrypt && !!defined?(EncryptedPostCreator)

        if delay && delay.to_i > 0 && automation_id
          pm[:execute_at] = delay.to_i.minutes.from_now
          pm[:sender] = sender
          pm[:automation_id] = automation_id
          pm[:prefers_encrypt] = prefers_encrypt
          DiscourseAutomation::PendingPm.create!(pm)
        else
          sender = User.find_by(username: sender)
          if !sender
            Rails.logger.warn "[discourse-automation] Did not send PM #{pm[:title]} - sender does not exist: `#{sender}`"
            return
          end

          pm[:target_usernames] = Array.wrap(pm[:target_usernames])
          pm[:target_group_names] = Array.wrap(pm[:target_group_names])
          pm[:target_emails] = Array.wrap(pm[:target_emails])

          if pm[:target_usernames].empty? && pm[:target_group_names].empty? &&
               pm[:target_emails].empty?
            Rails.logger.warn "[discourse-automation] Did not send PM - no target usernames, groups or emails"
            return
          end

          non_existing_targets = []

          if pm[:target_usernames].present?
            existing_target_usernames = User.where(username: pm[:target_usernames]).pluck(:username)
            if existing_target_usernames.length != pm[:target_usernames].length
              non_existing_targets += pm[:target_usernames] - existing_target_usernames
              pm[:target_usernames] = existing_target_usernames
            end
          end

          if pm[:target_group_names].present?
            existing_target_groups = Group.where(name: pm[:target_group_names]).pluck(:name)
            if existing_target_groups.length != pm[:target_group_names].length
              non_existing_targets += pm[:target_group_names] - existing_target_groups
              pm[:target_group_names] = existing_target_groups
            end
          end

          if pm[:target_emails].present?
            valid_emails = pm[:target_emails].select { |email| Email.is_valid?(email) }
            if valid_emails.length != pm[:target_emails].length
              non_existing_targets += pm[:target_emails] - valid_emails
              pm[:target_emails] = valid_emails
            end
          end

          post_created = false
          pm = pm.merge(archetype: Archetype.private_message)
          pm[:target_usernames] = pm[:target_usernames].join(",")
          pm[:target_group_names] = pm[:target_group_names].join(",")
          pm[:target_emails] = pm[:target_emails].join(",")

          if pm[:target_usernames].blank? && pm[:target_group_names].blank? &&
               pm[:target_emails].blank?
            Rails.logger.warn "[discourse-automation] Did not send PM #{pm[:title]} - no valid targets exist"
            return
          elsif non_existing_targets.any?
            Rails.logger.warn "[discourse-automation] Did not send PM #{pm[:title]} to all users - some do not exist: `#{non_existing_targets.join(",")}`"
          end

          post_created = EncryptedPostCreator.new(sender, pm).create if prefers_encrypt

          PostCreator.new(sender, pm).create! if !post_created
        end
      end
    end

    def self.add(identifier, &block)
      @all_scriptables = nil
      define_method("__scriptable_#{identifier}", &block)
    end

    def self.remove(identifier)
      @all_scriptables = nil
      undef_method("__scriptable_#{identifier}")
    end

    def self.all
      @all_scriptables ||=
        DiscourseAutomation::Scriptable.instance_methods(false).grep(/^__scriptable_/)
    end
  end
end
