# frozen_string_literal: true

module DiscourseAi
  module AiHelper
    class Painter
      def commission_thumbnails(input, user)
        return [] if input.blank?

        model = SiteSetting.ai_helper_illustrate_post_model

        if model == "stable_diffusion_xl"
          stable_diffusion_prompt = diffusion_prompt(input, user)
          return [] if stable_diffusion_prompt.blank?

          artifacts =
            DiscourseAi::Inference::StabilityGenerator
              .perform!(stable_diffusion_prompt)
              .dig(:artifacts)
              .to_a
              .map { |art| art[:base64] }

          base64_to_image(artifacts, user.id)
        elsif model == "dall_e_3"
          llm_model = find_llm_model_for_feature("illustrate_post")
          LlmCreditAllocation.check_credits!(llm_model) if llm_model

          attribution =
            I18n.t(
              "discourse_ai.ai_helper.painter.attribution.#{SiteSetting.ai_helper_illustrate_post_model}",
            )
          results =
            DiscourseAi::Inference::OpenAiImageGenerator.create_uploads!(
              input,
              model: "dall-e-3",
              user_id: user.id,
              title: attribution,
            )
          results.map { |result| UploadSerializer.new(result[:upload], root: false) }
        end
      end

      private

      def find_llm_model_for_feature(feature_name)
        persona_id = SiteSetting.ai_helper_post_illustrator_persona
        return nil if persona_id.blank?

        persona = AiPersona.find_by(id: persona_id)
        return nil if persona.blank?

        LlmModel.find_by(id: persona.default_llm_id)
      end

      def base64_to_image(artifacts, user_id)
        attribution =
          I18n.t(
            "discourse_ai.ai_helper.painter.attribution.#{SiteSetting.ai_helper_illustrate_post_model}",
          )

        artifacts.each_with_index.map do |art, i|
          f = Tempfile.new("v1_txt2img_#{i}.png")
          f.binmode
          f.write(Base64.decode64(art))
          f.rewind
          upload = UploadCreator.new(f, attribution).create_for(user_id)
          f.unlink

          UploadSerializer.new(upload, root: false)
        end
      end

      def diffusion_prompt(text, user)
        llm_model =
          AiPersona.find_by(id: SiteSetting.ai_helper_post_illustrator_persona)&.default_llm_id ||
            SiteSetting.ai_default_llm_model

        return nil if llm_model.blank?

        prompt =
          DiscourseAi::Completions::Prompt.new(
            <<~TEXT.strip,
          Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
          You'll find the post between <input></input> XML tags.
        TEXT
            messages: [{ type: :user, content: text, id: user.username }],
          )

        DiscourseAi::Completions::Llm.proxy(llm_model).generate(
          prompt,
          user: user,
          feature_name: "illustrate_post",
        )
      end
    end
  end
end
