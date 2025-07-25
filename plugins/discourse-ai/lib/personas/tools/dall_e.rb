# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class DallE < Tool
        def self.signature
          {
            name: name,
            description: "Renders images from supplied descriptions",
            parameters: [
              {
                name: "prompts",
                description:
                  "The prompts used to generate or create or draw the image (5000 chars or less, be creative) up to 4 prompts",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "aspect_ratio",
                description: "The aspect ratio (optional, square by default)",
                type: "string",
                required: false,
                enum: %w[tall square wide],
              },
            ],
          }
        end

        def self.name
          "dall_e"
        end

        def prompts
          parameters[:prompts]
        end

        def aspect_ratio
          parameters[:aspect_ratio]
        end

        def chain_next_response?
          false
        end

        def invoke
          # max 4 prompts
          max_prompts = prompts.take(4)
          progress = prompts.first

          yield(progress)

          results = nil

          size = "1024x1024"
          if aspect_ratio == "tall"
            size = "1024x1792"
          elsif aspect_ratio == "wide"
            size = "1792x1024"
          end

          results =
            DiscourseAi::Inference::OpenAiImageGenerator.create_uploads!(
              max_prompts,
              model: "dall-e-3",
              size: size,
              user_id: bot_user.id,
            )

          if results.blank?
            return { prompts: max_prompts, error: "Something went wrong, could not generate image" }
          end

          self.custom_raw = <<~RAW

            [grid]
            #{
            results
              .map { |item| "![#{item[:prompt].gsub(/\|\'\"/, "")}](#{item[:upload].short_url})" }
              .join(" ")
          }
            [/grid]
          RAW

          { prompts: results.map { |item| item[:prompt] } }
        end

        protected

        def description_args
          { prompt: prompts.first }
        end
      end
    end
  end
end
