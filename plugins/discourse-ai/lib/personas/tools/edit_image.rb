# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class EditImage < Tool
        def self.signature
          {
            name: name,
            description: "Renders images from supplied descriptions",
            parameters: [
              {
                name: "prompt",
                description:
                  "instructions for the image to be edited (5000 chars or less, be creative)",
                type: "string",
                required: true,
              },
              {
                name: "image_urls",
                description:
                  "The images to provides as context for the edit (minimum 1, maximum 10), use the short url eg: upload://qUm0DGR49PAZshIi7HxMd3cAlzn.png",
                type: "array",
                item_type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "edit_image"
        end

        def prompt
          parameters[:prompt]
        end

        def chain_next_response?
          !!@error
        end

        def image_urls
          parameters[:image_urls]
        end

        def invoke
          yield(prompt)

          return { prompt: prompt, error: "No valid images provided" } if image_urls.blank?

          sha1s = image_urls.map { |url| Upload.sha1_from_short_url(url) }.compact
          uploads = Upload.where(sha1: sha1s).order(created_at: :asc).limit(10).to_a

          return { prompt: prompt, error: "No valid images provided" } if uploads.blank?

          begin
            result =
              DiscourseAi::Inference::OpenAiImageGenerator.create_edited_upload!(
                uploads,
                prompt,
                user_id: bot_user.id,
                cancel_manager: context.cancel_manager,
              )
          rescue => e
            @error = e
            return { prompt: prompt, error: e.message }
          end

          if result.blank?
            @error = true
            return { prompt: prompt, error: "Something went wrong, could not generate image" }
          end

          self.custom_raw = "![#{result[:prompt].gsub(/\|\'\"/, "")}](#{result[:upload].short_url})"

          { prompt: result[:prompt], url: result[:upload].short_url }
        end

        protected

        def description_args
          { prompt: prompt }
        end
      end
    end
  end
end
