# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class CreateImage < Tool
        def self.signature
          {
            name: name,
            description: "Renders images from supplied descriptions",
            parameters: [
              {
                name: "prompts",
                description:
                  "The prompts used to generate or create or draw the image (5000 chars or less, be creative) up to 4 prompts, usually only supply a single prompt",
                type: "array",
                item_type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "create_image"
        end

        def prompts
          parameters[:prompts]
        end

        def chain_next_response?
          !!@error
        end

        def invoke
          # max 4 prompts
          max_prompts = prompts.take(4)
          progress = prompts.first

          yield(progress)

          results = nil

          begin
            results =
              DiscourseAi::Inference::OpenAiImageGenerator.create_uploads!(
                max_prompts,
                model: "gpt-image-1",
                user_id: bot_user.id,
                cancel_manager: context.cancel_manager,
              )
          rescue => e
            @error = e
            return { prompts: max_prompts, error: e.message }
          end

          if results.blank?
            @error = true
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

          {
            prompts: results.map { |item| { prompt: item[:prompt], url: item[:upload].short_url } },
          }
        end

        protected

        def description_args
          { prompt: prompts.first }
        end
      end
    end
  end
end
