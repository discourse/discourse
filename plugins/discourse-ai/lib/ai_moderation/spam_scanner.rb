# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamScanner
      POSTS_TO_SCAN = 3
      MINIMUM_EDIT_DIFFERENCE = 10
      EDIT_DELAY_MINUTES = 10
      MAX_AGE_TO_SCAN = 1.day
      MAX_RAW_SCAN_LENGTH = 5000

      SHOULD_SCAN_POST_CUSTOM_FIELD = "discourse_ai_should_scan_post"

      def self.new_post(post)
        return if !enabled?
        return if !should_scan_post?(post)

        flag_post_for_scanning(post)
      end

      def self.ensure_flagging_user!
        if !SiteSetting.ai_spam_detection_user_id.present?
          User.transaction do
            # prefer a "high" id for this bot
            id = User.where("id > -20").minimum(:id) - 1
            id = User.minimum(:id) - 1 if id == -100

            user =
              User.create!(
                id: id,
                username: UserNameSuggester.suggest("discourse_ai_spam"),
                name: "Discourse AI Spam Scanner",
                email: "#{SecureRandom.hex(10)}@invalid.invalid",
                active: true,
                approved: true,
                trust_level: TrustLevel[4],
                admin: true,
              )
            Group.user_trust_level_change!(user.id, user.trust_level)

            SiteSetting.ai_spam_detection_user_id = user.id
          end
        end
      end

      def self.flagging_user
        user = nil
        if SiteSetting.ai_spam_detection_user_id.present?
          user = User.find_by(id: SiteSetting.ai_spam_detection_user_id)
          ensure_safe_flagging_user!(user)
        end
        user || Discourse.system_user
      end

      def self.ensure_safe_flagging_user!(user)
        # only do repair on bot users, if somehow it is set to a human skip repairs
        return if !user.bot?
        user.update!(silenced_till: nil) if user.silenced?
        user.update!(trust_level: TrustLevel[4]) if user.trust_level != TrustLevel[4]
        user.update!(suspended_till: nil, suspended_at: nil) if user.suspended?
        user.update!(active: true) if !user.active?
      end

      def self.after_cooked_post(post)
        return if !enabled?
        return if !should_scan_post?(post)
        return if !post.custom_fields[SHOULD_SCAN_POST_CUSTOM_FIELD]
        return if post.updated_at < MAX_AGE_TO_SCAN.ago

        last_scan = AiSpamLog.where(post_id: post.id).order(created_at: :desc).first

        if last_scan && last_scan.created_at > EDIT_DELAY_MINUTES.minutes.ago
          delay_minutes =
            ((last_scan.created_at + EDIT_DELAY_MINUTES.minutes) - Time.current).to_i / 60
          Jobs.enqueue_in(delay_minutes.minutes, :ai_spam_scan, post_id: post.id)
        else
          Jobs.enqueue(:ai_spam_scan, post_id: post.id)
        end
      end

      def self.edited_post(post)
        return if !enabled?
        return if !should_scan_post?(post)
        return if scanned_max_times?(post)

        editor = post.last_editor
        return if editor && (editor.staff? || editor.bot?)

        previous_version = post.revisions.last&.modifications&.dig("raw", 0)
        current_version = post.raw

        return if !significant_change?(previous_version, current_version)

        flag_post_for_scanning(post)
      end

      def self.flag_post_for_scanning(post)
        post.custom_fields[SHOULD_SCAN_POST_CUSTOM_FIELD] = "true"
        post.save_custom_fields
      end

      def self.enabled?
        SiteSetting.ai_spam_detection_enabled && SiteSetting.discourse_ai_enabled
      end

      def self.should_scan_post?(post)
        return false if !post.present?
        return false if post.user.trust_level > TrustLevel[1]
        return false if post.topic.private_message?
        return false if post.user.bot?
        return false if post.user.staff?

        if Post
             .where(user_id: post.user_id)
             .joins(:topic)
             .where(topic: { archetype: Archetype.default })
             .limit(4)
             .count > 3
          return false
        end
        true
      end

      def self.scanned_max_times?(post)
        AiSpamLog.where(post_id: post.id).count >= 3
      end

      def self.significant_change?(previous_version, current_version)
        return true if previous_version.nil? # First edit should be scanned

        # Use Discourse's built-in levenshtein implementation
        distance =
          ScreenedEmail.levenshtein(previous_version.to_s[0...1000], current_version.to_s[0...1000])

        distance >= MINIMUM_EDIT_DIFFERENCE
      end

      def self.test_post(post, custom_instructions: nil, llm_id: nil)
        settings = AiModerationSetting.spam
        custom_instructions = custom_instructions || settings.custom_instructions.presence

        target_msg =
          build_target_content_msg(
            post,
            post.topic || Topic.with_deleted.find_by(id: post.topic_id),
          )
        custom_insts = custom_instructions || settings.custom_instructions.presence
        if custom_insts.present?
          custom_insts =
            "\n\nAdditional site-specific instructions provided by Staff:\n#{custom_insts}"
        end

        ctx =
          build_bot_context(
            feature_name: "spam_detection_test",
            messages: [target_msg],
            custom_instructions: custom_insts,
          )
        bot = build_scanner_bot(settings: settings, llm_id: llm_id)

        structured_output = nil
        llm_args = { feature_context: { post_id: post.id } }
        bot.reply(ctx, llm_args: llm_args) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        history = nil
        AiSpamLog
          .where(post: post)
          .order(:created_at)
          .limit(100)
          .each do |log|
            history ||= +"Scan History:\n"
            history << "date: #{log.created_at} is_spam: #{log.is_spam}\n"
          end

        log = +"Scanning #{post.url}\n\n"

        if history
          log << history
          log << "\n"
        end

        used_llm = bot.model
        log << "LLM: #{used_llm.name}\n\n"

        spam_persona = bot.persona
        used_prompt = spam_persona.craft_prompt(ctx, llm: used_llm).system_message_text
        log << "System Prompt: #{used_prompt}\n\n"

        text_content =
          if target_msg[:content].is_a?(Array)
            target_msg[:content].first
          else
            target_msg[:content]
          end

        log << "Context: #{text_content}\n\n"

        is_spam = is_spam?(structured_output)

        reasoning_insts = {
          type: :user,
          content: "Don't return a JSON this time. Explain your reasoning in plain text.",
        }
        ctx.messages = [
          target_msg,
          { type: :model, content: { spam: is_spam }.to_json },
          reasoning_insts,
        ]
        ctx.bypass_response_format = true

        reasoning = +""

        bot.reply(ctx, llm_args: llm_args.merge(max_tokens: 100)) do |partial, _, type|
          reasoning << partial if type.blank?
        end

        log << "#{reasoning.strip}"

        { is_spam: is_spam, log: log }
      end

      def self.perform_scan(post)
        return if !should_scan_post?(post)

        perform_scan!(post)
      end

      def self.perform_scan!(post)
        return if !enabled?
        settings = AiModerationSetting.spam
        return if !settings || !settings.llm_model || !settings.ai_persona

        target_msg = build_target_content_msg(post)
        custom_instructions = settings.custom_instructions.presence
        if custom_instructions.present?
          custom_instructions =
            "\n\nAdditional site-specific instructions provided by Staff:\n#{custom_instructions}"
        end

        ctx =
          build_bot_context(
            messages: [target_msg],
            custom_instructions: custom_instructions,
            user: self.flagging_user,
          )
        bot = build_scanner_bot(settings: settings, user: self.flagging_user)
        structured_output = nil

        begin
          llm_args = { feature_context: { post_id: post.id } }
          bot.reply(ctx, llm_args: llm_args) do |partial, _, type|
            structured_output = partial if type == :structured_output
          end

          is_spam = is_spam?(structured_output)

          log = AiApiAuditLog.order(id: :desc).where(feature_name: "spam_detection").first
          text_content =
            if target_msg[:content].is_a?(Array)
              target_msg[:content].first
            else
              target_msg[:content]
            end
          AiSpamLog.transaction do
            log =
              AiSpamLog.create!(
                post: post,
                llm_model: settings.llm_model,
                ai_api_audit_log: log,
                is_spam: is_spam,
                payload: text_content,
              )
            handle_spam(post, log) if is_spam
          end
        rescue StandardError => e
          # we need retries otherwise stuff will not be handled
          Discourse.warn_exception(
            e,
            message: "Discourse AI: Error in SpamScanner for post #{post.id}",
          )
          raise e
        end
      end

      def self.fix_spam_scanner_not_admin
        user = DiscourseAi::AiModeration::SpamScanner.flagging_user

        if user.present?
          user.update!(admin: true)
        else
          raise Discourse::NotFound
        end
      end

      private

      def self.build_bot_context(
        feature_name: "spam_detection",
        messages:,
        custom_instructions: nil,
        bypass_response_format: false,
        user: Discourse.system_user
      )
        DiscourseAi::Personas::BotContext
          .new(
            user: user,
            skip_tool_details: true,
            feature_name: feature_name,
            messages: messages,
            bypass_response_format: bypass_response_format,
          )
          .tap { |ctx| ctx.custom_instructions = custom_instructions if custom_instructions }
      end

      def self.build_scanner_bot(
        settings:,
        use_structured_output: true,
        llm_id: nil,
        user: Discourse.system_user
      )
        persona = settings.ai_persona.class_instance&.new

        llm_model = llm_id ? LlmModel.find(llm_id) : settings.llm_model

        DiscourseAi::Personas::Bot.as(user, persona: persona, model: llm_model)
      end

      def self.is_spam?(structured_output)
        structured_output.present? && structured_output.read_buffered_property(:spam)
      end

      def self.build_target_content_msg(post, topic = nil)
        topic ||= post.topic
        context = []

        # Clear distinction between reply and new topic
        if post.is_first_post?
          context << "NEW TOPIC POST ANALYSIS"
          context << "- Topic title: #{topic.title}"
          context << "- Category: #{topic.category&.name}"
        else
          context << "REPLY POST ANALYSIS"
          context << "- In topic: #{topic.title}"
          context << "- Category: #{topic.category&.name}"
          context << "- Topic started by: #{topic.user&.username}"

          if post.reply_to_post_number.present?
            parent =
              Post.with_deleted.find_by(topic_id: topic.id, post_number: post.reply_to_post_number)
            if parent
              context << "\nReplying to #{parent.user&.username}'s post:"
              context << "#{parent.raw[0..500]}..." if parent.raw.length > 500
              context << parent.raw if parent.raw.length <= 500
            end
          end
        end

        context << "\nPost Author Information:"
        if user = post.user # during test we may not have a user
          context << "- Username: #{user.username}\n"
          context << "- Email: #{user.email}\n"
          context << "- Account age: #{(Time.current - user.created_at).to_i / 86_400} days\n"
          context << "- Total posts: #{user.post_count}\n"
          context << "- Trust level: #{user.trust_level}\n"
          if info = location_info(user)
            context << "- Registration Location: #{info[:registration]}\n" if info[:registration]
            context << "- Last Location: #{info[:last]}\n" if info[:last]
          end
        end

        context << "\nPost Content (first #{MAX_RAW_SCAN_LENGTH} chars):\n"
        context << post.raw[0..MAX_RAW_SCAN_LENGTH]

        user_msg = { type: :user, content: context.join("\n") }

        upload_ids = post.upload_ids
        if upload_ids.present?
          user_msg[:content] = [user_msg[:content]]
          upload_ids.take(3).each { |upload_id| user_msg[:content] << { upload_id: upload_id } }
        end

        user_msg
      end

      def self.location_info(user)
        registration, last = nil
        if user.ip_address.present?
          info = DiscourseIpInfo.get(user.ip_address, resolve_hostname: true)
          last = "#{info[:location]} (#{info[:organization]})" if info && info[:location].present?
        end
        if user.registration_ip_address.present?
          info = DiscourseIpInfo.get(user.registration_ip_address, resolve_hostname: true)
          registration = "#{info[:location]} (#{info[:organization]})" if info &&
            info[:location].present?
        end

        rval = nil
        if registration || last
          rval = { registration: registration } if registration
          if last && last != registration
            rval ||= {}
            rval[:last] = last
          end
        end

        rval
      rescue => e
        Discourse.warn_exception(e, message: "Failed to lookup location info")
        nil
      end

      def self.handle_spam(post, log)
        url = "#{Discourse.base_url}/admin/plugins/discourse-ai/ai-spam"
        reason = I18n.t("discourse_ai.spam_detection.flag_reason", url: url)

        flagging_user = self.flagging_user

        result =
          PostActionCreator.new(
            flagging_user,
            post,
            PostActionType.types[:spam],
            reason: reason,
            queue_for_review: true,
          ).perform

        # Currently in core re-flagging something that is already flagged as spam
        # is not supported, long term we may want to support this but in the meantime
        # we should not be silencing/hiding if the PostActionCreator fails.
        if result.success?
          log.update!(reviewable: result.reviewable)

          reason = I18n.t("discourse_ai.spam_detection.silence_reason", url: url)
          silencer =
            UserSilencer.new(
              post.user,
              flagging_user,
              message: :too_many_spam_flags,
              post_id: post.id,
              reason: reason,
              keep_posts: true,
            )
          silencer.silence

          # silencer will not hide tl1 posts, so we do this here
          hide_post(post)
        else
          log.update!(
            error:
              "unable to flag post as spam, post action failed for post #{post.id} with error: '#{result.errors.full_messages.join(", ").truncate(3000)}'",
          )
        end
      end

      def self.hide_post(post)
        Post.where(id: post.id).update_all(
          [
            "hidden = true, hidden_reason_id = COALESCE(hidden_reason_id, ?)",
            Post.hidden_reasons[:new_user_spam_threshold_reached],
          ],
        )

        Topic.where(id: post.topic_id).update_all(visible: false) if post.post_number == 1
      end
    end
  end
end
