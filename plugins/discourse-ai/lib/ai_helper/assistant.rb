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

      def self.prompt_cache
        @prompt_cache ||= DiscourseAi::MultisiteHash.new("prompt_cache")
      end

      def self.clear_prompt_cache!
        prompt_cache.flush!
      end

      def initialize(helper_llm: nil, image_caption_llm: nil)
        @helper_llm = helper_llm
        @image_caption_llm = image_caption_llm
      end

      def available_prompts(user)
        key = "prompt_cache_#{I18n.locale}"
        prompts = self.class.prompt_cache.fetch(key) { self.all_prompts }

        prompts
          .map do |prompt|
            next if !user.in_any_groups?(prompt[:allowed_group_ids])

            if prompt[:name] == ILLUSTRATE_POST &&
                 SiteSetting.ai_helper_illustrate_post_model == "disabled"
              next
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
          .compact
      end

      def custom_locale_instructions(user = nil, force_default_locale)
        locale = SiteSetting.default_locale
        locale = user.effective_locale if !force_default_locale && user
        locale_hash = LocaleSiteSetting.language_names[locale]

        if locale != "en" && locale_hash
          locale_description = "#{locale_hash["name"]} (#{locale_hash["nativeName"]})"
          "It is imperative that you write your answer in #{locale_description}, you are interacting with a #{locale_description} speaking user. Leave tag names in English."
        else
          nil
        end
      end

      def attach_user_context(context, user = nil, force_default_locale: false)
        locale = SiteSetting.default_locale
        locale = user.effective_locale if user && !force_default_locale
        locale_hash = LocaleSiteSetting.language_names[locale]

        context.user_language = "#{locale_hash["name"]}"

        if user
          timezone = user&.user_option&.timezone || "UTC"
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
          DiscourseAi::Personas::BotContext.new(
            user: user,
            skip_tool_details: true,
            feature_name: "ai_helper",
            messages: [{ type: :user, content: user_input }],
            format_dates: helper_mode == REPLACE_DATES,
            custom_instructions: custom_locale_instructions(user, force_default_locale),
          )
        context = attach_user_context(context, user, force_default_locale: force_default_locale)

        bad_json = false
        json_summary_schema_key = bot.persona.response_format&.first.to_h

        schema_key = json_summary_schema_key["key"]&.to_sym
        schema_type = json_summary_schema_key["type"]

        if schema_type == "array"
          helper_response = []
        else
          helper_response = +""
        end

        buffer_blk =
          Proc.new do |partial, _, type|
            if type == :structured_output && schema_type
              helper_chunk = partial.read_buffered_property(schema_key)
              next if helper_chunk.nil? || helper_chunk.empty?

              if schema_type == "array"
                if helper_chunk.is_a?(Array)
                  helper_chunk.each do |item|
                    helper_response << item if helper_response.exclude?(item)
                  end
                end
              elsif schema_type == "string"
                helper_response << helper_chunk
              else
                helper_response = helper_chunk
              end

              block.call(helper_chunk) if block && !bad_json
            elsif type.blank?
              # Assume response is a regular completion.
              helper_response << partial
              block.call(partial) if block
            end
          end

        bot.reply(context, &buffer_blk)

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
        result = { type: prompt_type(helper_mode) }

        result[:suggestions] = (
          if result[:type] == :list
            helper_response.flatten.map { |suggestion| sanitize_result(suggestion) }
          else
            sanitized = sanitize_result(helper_response)
            result[:diff] = parse_diff(input, sanitized) if result[:type] == :diff
            [sanitized]
          end
        )

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
        streamed_diff = +""
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
          streamed_diff = parse_diff(input, partial_response) if type == :diff

          # Throttle updates and check for safe stream points
          if (streamed_result.length > 10 && (Time.now - start > 0.3)) || Rails.env.test?
            sanitized = sanitize_result(streamed_result)

            payload = { result: sanitized, diff: streamed_diff, done: false }
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

      def generate_image_caption(upload, user)
        bot = build_bot(IMAGE_CAPTION, user)
        force_default_locale = false

        context =
          DiscourseAi::Personas::BotContext.new(
            user: user,
            skip_tool_details: true,
            feature_name: IMAGE_CAPTION,
            messages: [
              {
                type: :user,
                content: ["Describe this image in a single sentence.", { upload_id: upload.id }],
              },
            ],
            custom_instructions: custom_locale_instructions(user, force_default_locale),
          )

        structured_output = nil

        buffer_blk =
          Proc.new do |partial, _, type|
            if type == :structured_output
              structured_output = partial
              bot.persona.response_format&.first.to_h
            end
          end

        bot.reply(context, llm_args: { max_tokens: 1024 }, &buffer_blk)

        raw_caption = ""

        if structured_output
          json_summary_schema_key = bot.persona.response_format&.first.to_h
          raw_caption =
            structured_output.read_buffered_property(json_summary_schema_key["key"]&.to_sym)
        end

        raw_caption.delete("|").squish.truncate_words(IMAGE_CAPTION_MAX_WORDS)
      end

      private

      def build_bot(helper_mode, user)
        persona_id = personas_prompt_map(include_image_caption: true).invert[helper_mode]
        raise Discourse::InvalidParameters.new(:mode) if persona_id.blank?

        persona_klass = AiPersona.find_by(id: persona_id)&.class_instance
        return if persona_klass.nil?

        llm_model = find_ai_helper_model(helper_mode, persona_klass)

        DiscourseAi::Personas::Bot.as(user, persona: persona_klass.new, model: llm_model)
      end

      def find_ai_helper_model(helper_mode, persona_klass)
        if helper_mode == IMAGE_CAPTION && @image_caption_llm.is_a?(LlmModel)
          return @image_caption_llm
        end

        return @helper_llm if helper_mode != IMAGE_CAPTION && @helper_llm.is_a?(LlmModel)
        self.class.find_ai_helper_model(helper_mode, persona_klass)
      end

      # Priorities are:
      #   1. Persona's default LLM
      #   2. SiteSetting.ai_default_llm_model (or newest LLM if not set)
      def self.find_ai_helper_model(helper_mode, persona_klass)
        model_id = persona_klass.default_llm_id || SiteSetting.ai_default_llm_model

        if model_id.present?
          LlmModel.find_by(id: model_id)
        else
          LlmModel.last
        end
      end

      def personas_prompt_map(include_image_caption: false)
        map = {
          SiteSetting.ai_helper_translator_persona.to_i => TRANSLATE,
          SiteSetting.ai_helper_title_suggestions_persona.to_i => GENERATE_TITLES,
          SiteSetting.ai_helper_proofreader_persona.to_i => PROOFREAD,
          SiteSetting.ai_helper_markdown_tables_persona.to_i => MARKDOWN_TABLE,
          SiteSetting.ai_helper_custom_prompt_persona.to_i => CUSTOM_PROMPT,
          SiteSetting.ai_helper_explain_persona.to_i => EXPLAIN,
          SiteSetting.ai_helper_post_illustrator_persona.to_i => ILLUSTRATE_POST,
          SiteSetting.ai_helper_smart_dates_persona.to_i => REPLACE_DATES,
        }

        if include_image_caption
          image_caption_persona = SiteSetting.ai_helper_image_caption_persona.to_i
          map[image_caption_persona] = IMAGE_CAPTION if image_caption_persona
        end

        map
      end

      def all_prompts
        AiPersona
          .where(id: personas_prompt_map.keys)
          .map do |ai_persona|
            prompt_name = personas_prompt_map[ai_persona.id]

            if prompt_name
              {
                name: prompt_name,
                translated_name:
                  I18n.t("discourse_ai.ai_helper.prompts.#{prompt_name}", default: nil) ||
                    prompt_name,
                prompt_type: prompt_type(prompt_name),
                icon: icon_map(prompt_name),
                location: location_map(prompt_name),
                allowed_group_ids: ai_persona.allowed_group_ids,
              }
            end
          end
          .compact
      end

      SANITIZE_REGEX_STR =
        %w[term context topic replyTo input output result]
          .map { |tag| "<#{tag}>\\n?|\\n?</#{tag}>" }
          .join("|")

      SANITIZE_REGEX = Regexp.new(SANITIZE_REGEX_STR, Regexp::IGNORECASE | Regexp::MULTILINE)

      def sanitize_result(result)
        result.gsub(SANITIZE_REGEX, "")
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

      def icon_map(name)
        case name
        when TRANSLATE
          "language"
        when GENERATE_TITLES
          "heading"
        when PROOFREAD
          "spell-check"
        when MARKDOWN_TABLE
          "table"
        when CUSTOM_PROMPT
          "comment"
        when EXPLAIN
          "question"
        when ILLUSTRATE_POST
          "images"
        when REPLACE_DATES
          "calendar-days"
        else
          nil
        end
      end

      def location_map(name)
        case name
        when TRANSLATE
          %w[composer post]
        when GENERATE_TITLES
          %w[composer]
        when PROOFREAD
          %w[composer post]
        when MARKDOWN_TABLE
          %w[composer]
        when CUSTOM_PROMPT
          %w[composer post]
        when EXPLAIN
          %w[post]
        when ILLUSTRATE_POST
          %w[composer]
        when REPLACE_DATES
          %w[composer]
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
