# frozen_string_literal: true

# Builds a Mail::Message we can use for sending. Optionally supports using a template
# for the body and subject
module Email
  class MessageBuilder
    attr_reader :template_args, :reply_by_email_key

    ALLOW_REPLY_BY_EMAIL_HEADER = "X-Discourse-Allow-Reply-By-Email"

    def initialize(to, opts = nil)
      @to = to
      @opts = opts || {}
      @template_args = {
        site_name: SiteSetting.title,
        email_prefix: SiteSetting.email_prefix.presence || SiteSetting.title,
        base_url: Discourse.base_url,
        user_preferences_url: "#{Discourse.base_url}/my/preferences",
        hostname: Discourse.current_hostname,
      }.merge!(@opts)
      if @template_args[:url].present?
        @template_args[:header_instructions] ||= I18n.t(
          "user_notifications.header_instructions",
          @template_args,
        )
        @visit_link_to_respond_key =
          DiscoursePluginRegistry.apply_modifier(
            :message_builder_visit_link_to_respond,
            "user_notifications.visit_link_to_respond",
            @opts,
            @to,
          )
        @reply_by_email_key =
          DiscoursePluginRegistry.apply_modifier(
            :message_builder_reply_by_email,
            "user_notifications.reply_by_email",
            @opts,
            @to,
          )

        if @opts[:include_respond_instructions] == false
          @template_args[:respond_instructions] = ""
          @template_args[:respond_instructions] = I18n.t(
            "user_notifications.pm_participants",
            @template_args,
          ) if @opts[:private_reply]
        else
          if @opts[:only_reply_by_email]
            string = +"user_notifications.only_reply_by_email"
            string << "_pm" if @opts[:private_reply]
          else
            string =
              (
                if allow_reply_by_email?
                  +@reply_by_email_key
                else
                  +@visit_link_to_respond_key
                end
              )
            string << "_pm" if @opts[:private_reply]
          end
          @template_args[:respond_instructions] = "---\n" + I18n.t(string, @template_args)
        end

        if @opts[:add_unsubscribe_link]
          unsubscribe_string =
            if @opts[:mailing_list_mode]
              "unsubscribe_mailing_list"
            elsif SiteSetting.unsubscribe_via_email_footer
              "unsubscribe_link_and_mail"
            else
              "unsubscribe_link"
            end
          @template_args[:unsubscribe_instructions] = I18n.t(unsubscribe_string, @template_args)
        end
      end
    end

    def subject
      if @opts[:template] &&
           TranslationOverride.exists?(
             locale: I18n.locale,
             translation_key: "#{@opts[:template]}.subject_template",
           )
        augmented_template_args =
          @template_args.merge(
            {
              site_name: @template_args[:email_prefix],
              optional_re: @opts[:add_re_to_subject] ? I18n.t("subject_re") : "",
              optional_pm: @opts[:private_reply] ? @template_args[:subject_pm] : "",
              optional_cat:
                (
                  if @template_args[:show_category_in_subject]
                    "[#{@template_args[:show_category_in_subject]}] "
                  else
                    ""
                  end
                ),
              optional_tags:
                (
                  if @template_args[:show_tags_in_subject]
                    "#{@template_args[:show_tags_in_subject]} "
                  else
                    ""
                  end
                ),
              topic_title: @template_args[:topic_title] ? @template_args[:topic_title] : "",
            },
          )
        subject = I18n.t("#{@opts[:template]}.subject_template", augmented_template_args)
      elsif @opts[:use_site_subject]
        subject = String.new(SiteSetting.email_subject)
        subject.gsub!("%{site_name}", @template_args[:email_prefix])
        subject.gsub!("%{optional_re}", @opts[:add_re_to_subject] ? I18n.t("subject_re") : "")
        subject.gsub!("%{optional_pm}", @opts[:private_reply] ? @template_args[:subject_pm] : "")
        subject.gsub!(
          "%{optional_cat}",
          (
            if @template_args[:show_category_in_subject]
              "[#{@template_args[:show_category_in_subject]}] "
            else
              ""
            end
          ),
        )
        subject.gsub!(
          "%{optional_tags}",
          @template_args[:show_tags_in_subject] ? "#{@template_args[:show_tags_in_subject]} " : "",
        )
        if @template_args[:topic_title]
          subject.gsub!("%{topic_title}", @template_args[:topic_title])
        end # must be last for safety
      elsif @opts[:use_topic_title_subject]
        subject = @opts[:add_re_to_subject] ? I18n.t("subject_re") : ""
        subject = "#{subject}#{@template_args[:topic_title]}"
      elsif @opts[:template]
        subject = I18n.t("#{@opts[:template]}.subject_template", @template_args)
      else
        subject = @opts[:subject]
      end
      DiscoursePluginRegistry.apply_modifier(:message_builder_subject, subject, @opts, @to)
    end

    def html_part
      return unless html_override = @opts[:html_override]

      if @template_args[:unsubscribe_instructions].present?
        unsubscribe_instructions =
          PrettyText.cook(@template_args[:unsubscribe_instructions], sanitize: false).html_safe
        html_override.gsub!("%{unsubscribe_instructions}", unsubscribe_instructions)
      else
        html_override.gsub!("%{unsubscribe_instructions}", "")
      end

      if @template_args[:header_instructions].present?
        header_instructions =
          PrettyText.cook(@template_args[:header_instructions], sanitize: false).html_safe
        html_override.gsub!("%{header_instructions}", header_instructions)
      else
        html_override.gsub!("%{header_instructions}", "")
      end

      if @template_args[:respond_instructions].present?
        respond_instructions =
          PrettyText.cook(@template_args[:respond_instructions], sanitize: false).html_safe
        html_override.gsub!("%{respond_instructions}", respond_instructions)
      else
        html_override.gsub!("%{respond_instructions}", "")
      end

      html =
        UserNotificationRenderer.render(
          template: "layouts/email_template",
          format: :html,
          locals: {
            html_body: html_override.html_safe,
          },
        )
      html = DiscoursePluginRegistry.apply_modifier(:message_builder_html_part, html, @opts, @to)

      Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body html
      end
    end

    def body
      body = nil

      if @opts[:template]
        body = I18n.t("#{@opts[:template]}.text_body_template", template_args).dup
      else
        body = @opts[:body].dup
      end

      if @template_args[:unsubscribe_instructions].present?
        body << "\n"
        body << @template_args[:unsubscribe_instructions]
      end
      DiscoursePluginRegistry.apply_modifier(:message_builder_body, body, @opts, @to)
    end

    def build_args
      args = {
        to: @to,
        subject: subject,
        body: body,
        charset: "UTF-8",
        from: from_value,
        cc: @opts[:cc],
        bcc: @opts[:bcc],
      }

      args[:delivery_method_options] = @opts[:delivery_method_options] if @opts[
        :delivery_method_options
      ]
      args[:delivery_method_options] = (args[:delivery_method_options] || {}).merge(
        return_response: true,
      )

      args
    end

    def header_args
      result = {}

      if @opts[:add_unsubscribe_link]
        if unsubscribe_url = @template_args[:unsubscribe_url].presence
          result["List-Unsubscribe"] = "<#{unsubscribe_url}>"
          result["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
        else
          result["List-Unsubscribe"] = "<#{@template_args[:user_preferences_url]}>"
        end
      end

      result["X-Discourse-Post-Id"] = @opts[:post_id].to_s if @opts[:post_id]
      result["X-Discourse-Post-Ids"] = @opts[:post_ids].join(",") if @opts[:post_ids].present?
      result["X-Discourse-Topic-Id"] = @opts[:topic_id].to_s if @opts[:topic_id]
      result["X-Discourse-Topic-Ids"] = @opts[:topic_ids].join(",") if @opts[:topic_ids].present?

      # at this point these have been filtered by the recipient's guardian for visibility,
      # see UserNotifications#send_notification_email
      result["X-Discourse-Tags"] = @template_args[:show_tags_in_subject] if @opts[
        :show_tags_in_subject
      ]
      result["X-Discourse-Category"] = @template_args[:show_category_in_subject] if @opts[
        :show_category_in_subject
      ]

      # please, don't send us automatic responses...
      result["X-Auto-Response-Suppress"] = "All"

      if !allow_reply_by_email?
        # This will end up being the notification_email, which is a
        # noreply address.
        result["Reply-To"] = from_value
      else
        # The only reason we use from address for reply to is for group
        # SMTP emails, where the person will be replying to the group's
        # email_username.
        if !@opts[:use_from_address_for_reply_to]
          result[ALLOW_REPLY_BY_EMAIL_HEADER] = true
          result["Reply-To"] = reply_by_email_address
        else
          # No point in adding a reply-to header if it is going to be identical
          # to the from address/alias. If the from option is not present, then
          # the default reply-to address is used.
          result["Reply-To"] = from_value if from_value != alias_email(@opts[:from])
        end
      end

      result.merge(MessageBuilder.custom_headers(SiteSetting.email_custom_headers))
    end

    def self.custom_headers(string)
      result = {}
      string
        .split("|")
        .each do |item|
          header = item.split(":", 2)
          if header.length == 2
            name = header[0].strip
            value = header[1].strip
            result[name] = value if name.length > 0 && value.length > 0
          end
        end unless string.nil?
      result
    end

    protected

    def allow_reply_by_email?
      SiteSetting.reply_by_email_enabled? && reply_by_email_address.present? &&
        @opts[:allow_reply_by_email]
    end

    def private_reply?
      allow_reply_by_email? && @opts[:private_reply]
    end

    def from_value
      return @from_value if @from_value
      @from_value = @opts[:from] || SiteSetting.notification_email
      @from_value = alias_email(@from_value)
    end

    def reply_by_email_address
      return @reply_by_email_address if @reply_by_email_address
      return nil if SiteSetting.reply_by_email_address.blank?

      @reply_by_email_address = SiteSetting.reply_by_email_address.dup

      @reply_by_email_address =
        if private_reply?
          alias_email(@reply_by_email_address)
        else
          site_alias_email(@reply_by_email_address)
        end
    end

    def alias_email(source)
      if @opts[:from_alias].blank? && SiteSetting.email_site_title.blank? &&
           SiteSetting.title.blank?
        return source
      end

      if @opts[:from_alias].present?
        %Q|"#{Email.cleanup_alias(@opts[:from_alias])}" <#{source}>|
      elsif source == SiteSetting.notification_email || source == SiteSetting.reply_by_email_address
        site_alias_email(source)
      else
        source
      end
    end

    def site_alias_email(source)
      from_alias = Email.site_title
      %Q|"#{Email.cleanup_alias(from_alias)}" <#{source}>|
    end
  end
end
