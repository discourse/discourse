# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Assistant
      IMAGE_CAPTION_MAX_WORDS = 50

      TRANSLATE = "translate"
      GENERATE_TITLES = "generate_titles"
      PROOFREAD = "proofread"
      MARKDOWN_TABLE = "markdown_table"
      CUSTOM_PROMPT = "custom_prompt"
      EXPLAIN = "explain"
      ILLUSTRATE_POST = "illustrate_post"
      REPLACE_DATES = "replace_dates"
      IMAGE_CAPTION = "image_caption"

      PROMPT_ICONS = {
        TRANSLATE => "language",
        GENERATE_TITLES => "discourse-h1",
        PROOFREAD => "spell-check",
        MARKDOWN_TABLE => "table",
        CUSTOM_PROMPT => "comment",
        EXPLAIN => "question",
        ILLUSTRATE_POST => "images",
        REPLACE_DATES => "calendar-days",
      }.freeze

      def self.prompt_cache
        @prompt_cache ||= DiscourseAi::MultisiteHash.new("prompt_cache")
      end

      def self.clear_prompt_cache!
        prompt_cache.flush!
      end

      def self.prompt_agent_ids
        agents_prompt_map.keys.compact.uniq
      end

      def initialize(helper_llm: nil, image_caption_llm: nil)
        @helper_llm = helper_llm
        @image_caption_llm = image_caption_llm
      end

      def available_prompts(user)
        key =
          if SiteSetting.granular_anonymous_and_logged_in_groups_permissions
            "prompt_cache_#{I18n.locale}_everyone_disallowed"
          else
            "prompt_cache_#{I18n.locale}_everyone_allowed"
          end
        prompts = self.class.prompt_cache.fetch(key) { all_prompts }

        prompts.filter_map do |prompt|
          next if !user.in_any_groups?(prompt[:allowed_group_ids])

          if prompt[:name] == ILLUSTRATE_POST
            agent = AiAgent.find_by(id: SiteSetting.ai_helper_post_illustrator_agent)
            next if agent.blank? || !agent_has_image_generation_tool?(agent)
          end

          # We cannot cache this. It depends on the user's effective_locale.
          if prompt[:name] == TRANSLATE
            locale = user.effective_locale
            locale_hash =
              LocaleSiteSetting.language_names[locale] ||
                LocaleSiteSetting.language_names[locale.split("_")[0]]
            translation =
              I18n.t(
                "discourse_ai.ai_helper.prompts.translate",
                language: locale_hash["nativeName"],
              ) || prompt[:name]

            prompt.merge(translated_name: translation)
          else
            prompt
          end
        end
      end

      def custom_locale_instructions(user = nil, force_default_locale)
        locale_instructions(helper_locale(user, force_default_locale))
      end

      def locale_instructions(locale)
        locale_hash = LocaleSiteSetting.language_names[locale]
        return if locale == "en" || !locale_hash

        locale_description = "#{locale_hash["name"]} (#{locale_hash["nativeName"]})"
        "It is imperative that you write your answer in #{locale_description}, you are interacting with a #{locale_description} speaking user. Leave tag names in English."
      end

      def attach_user_context(context, user = nil, force_default_locale: false)
        locale_hash = LocaleSiteSetting.language_names[helper_locale(user, force_default_locale)]

        context.user_language = "#{locale_hash["name"]}"

        if user
          timezone = user.user_option&.timezone || "UTC"
          current_time = Time.now.in_time_zone(timezone)

          temporal_context = {
            utc_date_time: current_time.iso8601,
            local_time: current_time.strftime("%H:%M"),
            user: {
              timezone: timezone,
              weekday: current_time.strftime("%A"),
            },
          }

          context.temporal_context = temporal_context.to_json
        end

        context
      end

      def generate_prompt(
        helper_mode,
        input,
        user,
        force_default_locale: false,
        custom_prompt: nil,
        &block
      )
        bot = build_bot(helper_mode, user)

        user_input = "<input>#{input}</input>"
        if helper_mode == CUSTOM_PROMPT && custom_prompt.present?
          user_input = "<input>#{custom_prompt}:\n#{input}</input>"
        end

        context =
          DiscourseAi::Agents::BotContext.new(
            user: user,
            skip_show_thinking: true,
            feature_name: "ai_helper",
            messages: [{ type: :user, content: user_input }],
            format_dates: helper_mode == REPLACE_DATES,
            custom_instructions: custom_locale_instructions(user, force_default_locale),
          )
        context = attach_user_context(context, user, force_default_locale: force_default_locale)

        json_summary_schema_key = bot.agent.response_format&.first.to_h

        schema_key = json_summary_schema_key["key"]&.to_sym
        schema_type = json_summary_schema_key["type"]

        structured_output = nil
        helper_response = +""

        buffer_blk =
          Proc.new do |partial, _, type|
            if type == :structured_output && schema_type
              structured_output = partial

              if schema_type == "string"
                partial.read_buffered_property_chunk(schema_key) do |helper_chunk|
                  helper_response << helper_chunk
                  block.call(helper_chunk) if block
                end
              end
            elsif type.blank?
              # Assume response is a regular completion.
              helper_response << partial
              block.call(partial) if block
            end
          end

        bot.reply(context, &buffer_blk)

        if schema_type && schema_type != "string"
          # Non-string properties aren't streamed to callers; a single read at
          # the end avoids transient placeholders the partial-JSON parser emits
          # for incomplete elements (e.g. a trailing nil while an array is
          # mid-stream).
          helper_response = structured_output&.read_buffered_property(schema_key)
        end

        helper_response
      end

      def generate_and_send_prompt(
        helper_mode,
        input,
        user,
        force_default_locale: false,
        custom_prompt: nil
      )
        helper_response =
          generate_prompt(
            helper_mode,
            input,
            user,
            force_default_locale: force_default_locale,
            custom_prompt: custom_prompt,
          )
        type = prompt_type(helper_mode)
        return { type:, suggestions: list_suggestions(helper_response) } if type == :list

        sanitized = sanitize_result(helper_response)
        result = { type:, suggestions: [sanitized] }
        result[:diff] = parse_diff(input, sanitized) if type == :diff
        result
      end

      def stream_prompt(
        helper_mode,
        input,
        user,
        channel,
        force_default_locale: false,
        client_id: nil,
        custom_prompt: nil
      )
        streamed_result = +""
        start = Time.now
        type = prompt_type(helper_mode)

        generate_prompt(
          helper_mode,
          input,
          user,
          force_default_locale: force_default_locale,
          custom_prompt: custom_prompt,
        ) do |partial_response|
          streamed_result << partial_response

          # Throttle updates
          if (streamed_result.length > 10 && (Time.now - start > 0.3)) || Rails.env.test?
            sanitized = sanitize_result(streamed_result)

            payload = { result: sanitized, done: false }
            publish_update(channel, payload, user, client_id: client_id)
            start = Time.now
          end
        end

        final_diff = parse_diff(input, streamed_result) if type == :diff

        sanitized_result = sanitize_result(streamed_result)
        if sanitized_result.present?
          publish_update(
            channel,
            { result: sanitized_result, diff: final_diff, done: true },
            user,
            client_id: client_id,
          )
        end
      end

      def generate_image_caption(upload, user, locale: nil, post: nil, skip_access_check: false)
        bot = build_bot(IMAGE_CAPTION, user, skip_access_check: skip_access_check)
        custom_instructions =
          if locale.present?
            locale_instructions(locale)
          else
            custom_locale_instructions(user, false)
          end

        context =
          DiscourseAi::Agents::BotContext.new(
            post: post,
            user: user,
            skip_show_thinking: true,
            feature_name: IMAGE_CAPTION,
            messages: [
              {
                type: :user,
                content: ["Describe this image in a single sentence.", { upload_id: upload.id }],
              },
            ],
            custom_instructions: custom_instructions,
          )

        structured_output = nil

        bot.reply(context, llm_args: { max_response_tokens: 1024 }) do |partial, _, type|
          structured_output = partial if type == :structured_output
        end

        raw_caption = ""

        if structured_output
          json_summary_schema_key = bot.agent.response_format&.first.to_h
          raw_caption =
            structured_output.read_buffered_property(json_summary_schema_key["key"]&.to_sym)
        end

        raw_caption.delete("|").squish.truncate_words(IMAGE_CAPTION_MAX_WORDS)
      end

      def ensure_mode_access!(helper_mode, user)
        ai_agent = ai_agent_for_mode(helper_mode)
        return if ai_agent.nil?

        raise Discourse::InvalidAccess if !user.in_any_groups?(ai_agent.allowed_group_ids.to_a)

        ai_agent
      end

      def ensure_mode_access_for_location!(helper_mode, user, location)
        ensure_mode_access!(helper_mode, user)
        raise Discourse::InvalidAccess if !location_map(helper_mode).include?(location)
      end

      private

      def agent_has_image_generation_tool?(agent)
        agent&.has_image_generation_tool?
      rescue StandardError => e
        Rails.logger.warn(
          "Failed to check image generation tool for agent #{agent&.id}: #{e.message}",
        )
        false
      end

      def ai_agent_for_mode(helper_mode)
        agent_id = agents_prompt_map(include_image_caption: true).invert[helper_mode]
        raise Discourse::InvalidParameters.new(:mode) if agent_id.blank?

        AiAgent.find_by(id: agent_id)
      end

      def build_bot(helper_mode, user, skip_access_check: false)
        ai_agent =
          if skip_access_check
            ai_agent_for_mode(helper_mode)
          else
            ensure_mode_access!(helper_mode, user)
          end
        return if ai_agent.nil?

        agent_klass = ai_agent.class_instance
        return if agent_klass.nil?

        llm_model = find_ai_helper_model(helper_mode, agent_klass)

        DiscourseAi::Agents::Bot.as(user, agent: agent_klass.new, model: llm_model)
      end

      def find_ai_helper_model(helper_mode, agent_klass)
        if helper_mode == IMAGE_CAPTION && @image_caption_llm.is_a?(LlmModel)
          return @image_caption_llm
        end

        return @helper_llm if helper_mode != IMAGE_CAPTION && @helper_llm.is_a?(LlmModel)
        self.class.find_ai_helper_model(helper_mode, agent_klass)
      end

      # Priorities are:
      #   1. Agent's default LLM
      #   2. SiteSetting.ai_default_llm_model (or newest LLM if not set)
      def self.find_ai_helper_model(helper_mode, agent_klass)
        model_id = agent_klass.default_llm_id || SiteSetting.ai_default_llm_model

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end

      def self.agents_prompt_map(include_image_caption: false)
        map = {
          SiteSetting.ai_helper_translator_agent.to_i => TRANSLATE,
          SiteSetting.ai_helper_title_suggestions_agent.to_i => GENERATE_TITLES,
          SiteSetting.ai_helper_proofreader_agent.to_i => PROOFREAD,
          SiteSetting.ai_helper_markdown_tables_agent.to_i => MARKDOWN_TABLE,
          SiteSetting.ai_helper_custom_prompt_agent.to_i => CUSTOM_PROMPT,
          SiteSetting.ai_helper_explain_agent.to_i => EXPLAIN,
          SiteSetting.ai_helper_post_illustrator_agent.to_i => ILLUSTRATE_POST,
          SiteSetting.ai_helper_smart_dates_agent.to_i => REPLACE_DATES,
        }

        map[SiteSetting.ai_image_caption_agent.to_i] = IMAGE_CAPTION if include_image_caption
        map
      end

      def agents_prompt_map(include_image_caption: false)
        self.class.agents_prompt_map(include_image_caption:)
      end

      def helper_locale(user, force_default_locale)
        user && !force_default_locale ? user.effective_locale : SiteSetting.default_locale
      end

      def all_prompts
        prompt_names = agents_prompt_map

        AiAgent
          .where(id: prompt_names.keys)
          .map do |ai_agent|
            prompt_name = prompt_names[ai_agent.id]
            {
              name: prompt_name,
              translated_name:
                I18n.t("discourse_ai.ai_helper.prompts.#{prompt_name}", default: nil) ||
                  prompt_name,
              prompt_type: prompt_type(prompt_name),
              icon: PROMPT_ICONS[prompt_name],
              location: location_map(prompt_name),
              allowed_group_ids: ai_agent.allowed_group_ids,
            }
          end
      end

      SANITIZE_REGEX_STR =
        %w[term context topic replyTo input output result]
          .map { |tag| "<#{tag}>\\n?|\\n?</#{tag}>" }
          .join("|")

      SANITIZE_REGEX = Regexp.new(SANITIZE_REGEX_STR, Regexp::IGNORECASE | Regexp::MULTILINE)

      def sanitize_result(result)
        result.gsub(SANITIZE_REGEX, "")
      end

      # The mode's agent may not declare an array response format, and providers
      # don't always enforce the schema, so the response may not be a list of strings.
      def list_suggestions(response)
        return [] if !response.is_a?(Array)

        response.flatten.grep(String).map { |suggestion| sanitize_result(suggestion) }.compact_blank
      end

      def publish_update(channel, payload, user, client_id: nil)
        # when publishing we make sure we do not keep large backlogs on the channel
        # and make sure we clear the streaming info after 60 seconds
        # this ensures we do not bloat redis
        if client_id
          MessageBus.publish(
            channel,
            payload,
            user_ids: [user.id],
            client_ids: [client_id],
            max_backlog_age: 60,
          )
        else
          MessageBus.publish(channel, payload, user_ids: [user.id], max_backlog_age: 60)
        end
      end

      def location_map(name)
        case name
        when TRANSLATE, PROOFREAD, CUSTOM_PROMPT
          %w[composer post]
        when GENERATE_TITLES, MARKDOWN_TABLE, ILLUSTRATE_POST, REPLACE_DATES
          %w[composer]
        when EXPLAIN
          %w[post]
        else
          %w[]
        end
      end

      def prompt_type(prompt_name)
        if [PROOFREAD, MARKDOWN_TABLE, REPLACE_DATES, CUSTOM_PROMPT].include?(prompt_name)
          return :diff
        end

        return :list if [ILLUSTRATE_POST, GENERATE_TITLES].include?(prompt_name)

        :text
      end

      def parse_diff(text, suggestion)
        cooked_text = PrettyText.cook(text)
        cooked_suggestion = PrettyText.cook(suggestion)

        DiscourseDiff.new(cooked_text, cooked_suggestion).inline_html
      end
    end
  end
end
