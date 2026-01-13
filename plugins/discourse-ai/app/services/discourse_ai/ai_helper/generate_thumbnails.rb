# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class GenerateThumbnails
      include Service::Base

      params do
        attribute :text, :string

        validates :text, presence: true
        validates :text, length: { maximum: 10_000 }
      end

      model :persona
      policy :has_image_generation_tool
      model :llm_model
      step :generate_images
      step :parse_uploads
      step :serialize_thumbnails

      private

      def fetch_persona
        persona_id = SiteSetting.ai_helper_post_illustrator_persona
        AiPersona.find_by(id: persona_id)
      end

      def has_image_generation_tool(persona:)
        persona.has_image_generation_tool?
      end

      def fetch_llm_model(persona:)
        model =
          LlmModel.find_by(id: persona.default_llm_id) ||
            LlmModel.find_by(id: SiteSetting.ai_default_llm_model)
        fail!("llm_model_not_configured") if model.nil?
        model
      end

      def generate_images(persona:, llm_model:, params:, guardian:)
        bot =
          DiscourseAi::Personas::Bot.as(
            guardian.user,
            persona: persona.class_instance.new,
            model: llm_model,
          )

        bot_context =
          DiscourseAi::Personas::BotContext.new(
            user: guardian.user,
            feature_name: "illustrate_post",
            messages: [{ type: :user, content: params.text }],
          )

        captured_custom_raw = nil

        bot.reply(bot_context) do |partial, custom_raw, type|
          # Bot calls callback twice with custom_raw:
          # 1. During invoke: ("", custom_raw_value, :partial_invoke) - custom_raw in 2nd param
          # 2. After invoke: (custom_raw_value, nil, :custom_raw) - custom_raw in 1st param
          if type == :partial_invoke || type == :custom_raw
            captured_value = type == :partial_invoke ? custom_raw : partial
            captured_custom_raw = captured_value if captured_value.present?
          end
        end

        context[:captured_custom_raw] = captured_custom_raw
        fail!("no_image_generated") if captured_custom_raw.blank?
      rescue LlmCreditAllocation::CreditLimitExceeded
        raise
      rescue => e
        Rails.logger.error(
          "Image generation failed: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}",
        )
        fail!("no_image_generated")
      end

      def parse_uploads
        captured_custom_raw = context[:captured_custom_raw]
        upload_short_urls = captured_custom_raw.scan(%r{upload://[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)?})

        context[:upload_short_urls] = upload_short_urls
        fail!("no_image_generated") if upload_short_urls.blank?
      end

      def serialize_thumbnails
        upload_short_urls = context[:upload_short_urls]

        thumbnails =
          upload_short_urls
            .map do |short_url|
              upload = Upload.find_by(sha1: Upload.sha1_from_short_url(short_url))
              UploadSerializer.new(upload, root: false).as_json if upload
            end
            .compact

        context[:thumbnails] = thumbnails
      end
    end
  end
end
