# frozen_string_literal: true

module DiscourseAi
  module AiModeration
    class SpamScanner
      MINIMUM_EDIT_DIFFERENCE = 10
      EDIT_DELAY_MINUTES = 10
      MAX_AGE_TO_SCAN = 1.day
      MAX_RAW_SCAN_LENGTH = 5000

      SHOULD_SCAN_POST_CUSTOM_FIELD = "discourse_ai_should_scan_post"

      DECISION_FEATURE_NAME = "spam_detection"
      SPAM_QUESTION_NAME = "spam"
      SPAM_QUESTION_INSTRUCTIONS = <<~TEXT.squish
        Is this forum post spam? Answer yes for unsolicited promotion or advertising, link
        dropping, SEO or bot-generated content, gibberish, or replies unrelated to the thread.
        Answer no for genuine questions, answers, feedback and discussion, even from new users or
        non-native speakers.
      TEXT
      # A decision model settles posts outside these bounds; the LLM decides the rest.
      CLEARLY_NOT_SPAM_PROBABILITY = 0.05
      CLEARLY_SPAM_PROBABILITY = 0.9
      # Without an LLM to settle unsure posts, one cutoff decides them all.
      DECISION_ONLY_SPAM_PROBABILITY = 0.5
      MAX_DECISION_IMAGE_PIXELS = 1_600_000

      def self.new_post(post)
        return if !enabled?
        return if !should_scan_post?(post)
        return if approved_from_review_queue?(post)

        flag_post_for_scanning(post)
      end

      def self.approved_from_review_queue?(post)
        ReviewableQueuedPost.approved.exists?(target: post)
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

        editor = post.last_editor
        return if editor && (editor.staff? || editor.bot?)

        scan_args = { post_id: post.id, triggering_user_id: post.last_editor_id || post.user_id }
        last_scan = AiSpamLog.where(post_id: post.id).order(created_at: :desc).first

        if last_scan && last_scan.created_at > EDIT_DELAY_MINUTES.minutes.ago
          delay_minutes =
            ((last_scan.created_at + EDIT_DELAY_MINUTES.minutes) - Time.current).to_i / 60
          Jobs.enqueue_in(delay_minutes.minutes, :ai_spam_scan, scan_args)
        else
          Jobs.enqueue(:ai_spam_scan, scan_args)
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
        return false if post.user.trust_level > SiteSetting.ai_spam_detection_max_trust_level
        return false if post.topic.private_message?
        return false if post.user.bot?
        return false if post.user.staff?

        max_post_count = SiteSetting.ai_spam_detection_max_post_count
        if Post
             .where(user_id: post.user_id)
             .joins(:topic)
             .where(topic: { archetype: Archetype.default })
             .limit(max_post_count + 1)
             .count > max_post_count
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

      def self.test_post(
        post,
        custom_instructions: nil,
        llm_model: AiModerationSetting.spam&.llm_model,
        decision_model: AiModerationSetting.spam&.decision_model
      )
        settings = AiModerationSetting.spam
        custom_instructions =
          staff_instructions(custom_instructions || settings&.custom_instructions.presence)

        target_msg =
          build_target_content_msg(
            post,
            post.topic || Topic.with_deleted.find_by(id: post.topic_id),
          )

        verdict = {}
        if decision_model
          verdict =
            decision_verdict(
              decision_model,
              target_msg,
              custom_instructions,
              decides_alone: llm_model.nil?,
            ) || {}
        end

        system_prompt = decision_instructions(custom_instructions) if decision_model
        if verdict[:is_spam].nil?
          ctx =
            build_bot_context(
              feature_name: "spam_detection_test",
              messages: [target_msg],
              custom_instructions: custom_instructions,
            )
          bot = build_scanner_bot(settings: settings, llm_model: llm_model)

          structured_output = nil
          llm_args = { feature_context: { post_id: post.id } }
          bot.reply(ctx, llm_args: llm_args) do |partial, _, type|
            structured_output = partial if type == :structured_output
          end

          verdict.merge!(
            is_spam: is_spam?(structured_output),
            reason: extract_reason(structured_output),
            llm_model: bot.model,
          )
          system_prompt = bot.agent.craft_prompt(ctx, llm: bot.model.to_llm).system_message_text
        end

        history = nil
        AiSpamLog
          .where(post: post)
          .order(:created_at)
          .limit(100)
          .each do |log|
            history ||= +"Scan History:\n"
            history << "date: #{log.created_at} is_spam: #{log.is_spam}"
            history << " reason: #{log.reason}" if log.reason.present?
            history << "\n"
          end

        {
          is_spam: verdict[:is_spam],
          reason: verdict[:reason],
          llm_name: verdict[:llm_model]&.name,
          decision_model_name: decision_model&.display_name,
          spam_probability: verdict[:spam_probability],
          system_prompt: system_prompt,
          sent_message: text_content(target_msg),
          scan_history: history,
          post_url: post.url,
        }
      end

      def self.perform_scan(post, triggering_user_id: nil)
        return if !should_scan_post?(post)

        perform_scan!(post, triggering_user_id: triggering_user_id)
      end

      def self.perform_scan!(post, triggering_user_id: nil)
        return if !enabled?
        settings = AiModerationSetting.spam
        return if !settings
        decision_model = settings.decision_model
        return if !decision_model && !llm_configured?(settings)

        target_msg = build_target_content_msg(post)
        custom_instructions = staff_instructions(settings.custom_instructions.presence)

        begin
          verdict = {}
          if decision_model
            verdict =
              decision_verdict(
                decision_model,
                target_msg,
                custom_instructions,
                decides_alone: !llm_configured?(settings),
              ) || {}
          end
          if verdict[:is_spam].nil?
            verdict.merge!(llm_verdict(settings, target_msg, custom_instructions, post:))
          end

          AiSpamLog.transaction do
            log =
              AiSpamLog.create!(
                post: post,
                payload: text_content(target_msg),
                ai_api_audit_log_id: verdict[:audit_log_id],
                **verdict.slice(:is_spam, :reason, :spam_probability, :llm_model, :decision_model),
              )
            handle_spam(post, log, triggering_user_id: triggering_user_id) if log.is_spam
          end
        rescue DiscourseAi::Decisions::CreditLimitExceeded
          # with no LLM to fall back on, the post goes unscanned until credits reset
          Rails.logger.warn(
            "Discourse AI: Spam scan skipped for post #{post.id}, the decision model is out of credits",
          )
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
        DiscourseAi::Agents::BotContext
          .new(
            user: user,
            skip_show_thinking: true,
            feature_name: feature_name,
            messages: messages,
            bypass_response_format: bypass_response_format,
          )
          .tap { |ctx| ctx.custom_instructions = custom_instructions if custom_instructions }
      end

      def self.build_scanner_bot(
        settings:,
        llm_model: settings.llm_model,
        user: Discourse.system_user
      )
        agent = settings.ai_agent.class_instance&.new

        DiscourseAi::Agents::Bot.as(user, agent: agent, model: llm_model)
      end

      def self.llm_configured?(settings)
        settings.llm_model.present? && settings.ai_agent.present?
      end

      def self.staff_instructions(custom_instructions)
        return if custom_instructions.blank?

        "\n\nAdditional site-specific instructions provided by Staff:\n#{custom_instructions}"
      end

      def self.decision_instructions(custom_instructions)
        "#{SPAM_QUESTION_INSTRUCTIONS}#{custom_instructions}"
      end

      def self.text_content(target_msg)
        content = target_msg[:content]
        content.is_a?(Array) ? content.first : content
      end

      # @return [Hash, nil] the verdict, with a nil :is_spam when the LLM should decide; nil
      #   when the decision model could not answer and the LLM should decide
      # @raise [DiscourseAi::Decisions::Error] when the decision model decides alone
      def self.decision_verdict(decision_model, target_msg, custom_instructions, decides_alone:)
        result =
          decision_model.decide(
            text_content(target_msg),
            questions: [
              {
                name: SPAM_QUESTION_NAME,
                type: "yes_no",
                instructions: decision_instructions(custom_instructions),
              },
            ],
            feature_name: DECISION_FEATURE_NAME,
            user: Discourse.system_user,
            images: decision_images(decision_model, target_msg),
          )
        verdict = { decision_model:, audit_log_id: result.audit_log_id }

        answer = result[SPAM_QUESTION_NAME]
        if answer.refusal?
          return if !decides_alone
          return(
            verdict.merge(
              is_spam: false,
              reason: I18n.t("discourse_ai.spam_detection.decision_refused"),
            )
          )
        end

        probability = answer.probability
        is_spam =
          if decides_alone
            probability >= DECISION_ONLY_SPAM_PROBABILITY
          elsif probability >= CLEARLY_SPAM_PROBABILITY
            true
          elsif probability <= CLEARLY_NOT_SPAM_PROBABILITY
            false
          end
        reason =
          if !is_spam.nil?
            I18n.t(
              "discourse_ai.spam_detection.decision_reason",
              probability: (probability * 100).round,
            )
          end

        verdict.merge(is_spam:, reason:, spam_probability: probability)
      rescue DiscourseAi::Decisions::Error => e
        raise if decides_alone

        Rails.logger.warn("Discourse AI: Spam decision model failed, the LLM decides: #{e.class}")
        nil
      end

      # Images only add evidence, so a post whose images cannot be prepared is judged on its text.
      def self.decision_images(decision_model, target_msg)
        return [] if !decision_model.vision_enabled || !target_msg[:content].is_a?(Array)

        upload_ids = target_msg[:content].filter_map { |part| part[:upload_id] if part.is_a?(Hash) }
        DiscourseAi::Completions::UploadEncoder
          .encode(upload_ids:, max_pixels: MAX_DECISION_IMAGE_PIXELS)
          .map { |image| "data:#{image[:mime_type]};base64,#{image[:base64]}" }
      rescue StandardError => e
        Rails.logger.warn("Discourse AI: Could not prepare images for spam detection: #{e.message}")
        []
      end

      def self.llm_verdict(settings, target_msg, custom_instructions, post:)
        ctx =
          build_bot_context(
            messages: [target_msg],
            custom_instructions: custom_instructions,
            user: flagging_user,
          )
        bot = build_scanner_bot(settings: settings, user: flagging_user)
        structured_output = nil

        llm_args = { feature_context: { post_id: post.id } }
        bot.reply(ctx, llm_args: llm_args) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        {
          is_spam: is_spam?(structured_output),
          reason: extract_reason(structured_output),
          llm_model: settings.llm_model,
          audit_log_id:
            AiApiAuditLog.order(id: :desc).where(feature_name: "spam_detection").pick(:id),
        }
      end

      def self.is_spam?(structured_output)
        structured_output.present? && structured_output.read_buffered_property(:spam)
      end

      def self.extract_reason(structured_output)
        return nil if structured_output.blank?
        structured_output.read_buffered_property(:reason)
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

      def self.handle_spam(post, log, triggering_user_id: nil)
        if post_has_existing_flag?(post)
          log.update!(error: "skipped because post already has a flag")
          return
        end

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

          if triggering_user_id.present? && triggering_user_id.to_i == post.user_id
            reason = I18n.t("discourse_ai.spam_detection.silence_reason", url: url)
            silencer =
              UserSilencer.new(
                post.user,
                flagging_user,
                message: :too_many_spam_flags,
                post_id: post.id,
                reviewable_id: result.reviewable&.id,
                reason: reason,
                keep_posts: true,
              )
            silencer.auto_silence

            # silencer will not hide tl1 posts, so we do this here
            hide_post(post)
          end
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

      def self.post_has_existing_flag?(post)
        PostAction.active.flags.where(post: post).exists?
      end
    end
  end
end
