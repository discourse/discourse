# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Image < Tool
        def self.signature
          {
            name: name,
            description:
              "Renders an image from the description (remove all connector words, keep it to 40 words or less). Despite being a text based bot you can generate images! (when user asks to draw, paint or other synonyms try this)",
            parameters: [
              {
                name: "prompts",
                description:
                  "The prompts used to generate or create or draw the image (40 words or less, be creative) up to 4 prompts",
                type: "array",
                item_type: "string",
                required: true,
              },
              {
                name: "seeds",
                description:
                  "The seed used to generate the image (optional) - can be used to retain image style on amended prompts",
                type: "array",
                item_type: "integer",
              },
              {
                name: "aspect_ratio",
                description: "The aspect ratio of the image (optional defaults to 1:1)",
                type: "string",
                required: false,
                enum: %w[16:9 1:1 21:9 2:3 3:2 4:5 5:4 9:16 9:21],
              },
            ],
          }
        end

        def self.name
          "image"
        end

        def initialize(*args, **kwargs)
          super
          @chain_next_response = false
        end

        def prompts
          parameters[:prompts]
        end

        def aspect_ratio
          parameters[:aspect_ratio]
        end

        def seeds
          parameters[:seeds]
        end

        def chain_next_response?
          @chain_next_response
        end

        def invoke
          # Find available custom image generation tools
          custom_tools = self.class.available_custom_image_tools

          if custom_tools.empty?
            @chain_next_response = true
            return(
              {
                prompts: prompts,
                error:
                  "No image generation tools configured. Please configure an image generation tool via the admin UI to use this feature.",
                give_up: true,
              }
            )
          end

          # Use the first available custom image tool
          tool_class = custom_tools.first

          # Map aspect ratio to size parameter if provided
          size = aspect_ratio_to_size(aspect_ratio)

          # Generate images for each prompt (up to 4)
          selected_prompts = prompts.take(4)
          progress = prompts.first
          yield(progress)

          uploads = []
          errors = []

          selected_prompts.each_with_index do |prompt, index|
            begin
              # Create tool instance with parameters
              tool_params = { prompt: prompt }
              tool_params[:size] = size if size

              tool_instance =
                tool_class.new(tool_params, bot_user: bot_user, llm: llm, context: context)

              # Invoke the tool
              tool_instance.invoke { |_progress| }

              # Extract the custom_raw which contains the generated image markdown
              if tool_instance.custom_raw.present?
                # Parse the upload short_url from the markdown
                upload_match = tool_instance.custom_raw.match(%r{!\[.*?\]\((upload://[^)]+)\)})
                if upload_match
                  short_url = upload_match[1]
                  sha1 = Upload.sha1_from_short_url(short_url)
                  upload = Upload.find_by(sha1: sha1) if sha1
                  if upload
                    uploads << {
                      prompt: prompt,
                      upload: upload,
                      seed: nil, # Custom tools don't provide seeds
                    }
                  end
                end
              end
            rescue => e
              Rails.logger.warn("Failed to generate image for prompt #{prompt}: #{e}")
              errors << e.message
            end
          end

          if uploads.empty?
            @chain_next_response = true
            return(
              {
                prompts: prompts,
                error:
                  "Failed to generate images. #{errors.first || "Please check your image generation tool configuration."}",
                give_up: true,
              }
            )
          end

          @custom_raw = <<~RAW

          [grid]
          #{
            uploads
              .map { |item| "![#{item[:prompt].gsub(/\|\'\"/, "")}](#{item[:upload].short_url})" }
              .join(" ")
          }
          [/grid]
        RAW

          {
            prompts: uploads.map { |item| item[:prompt] },
            seeds: uploads.map { |item| item[:seed] },
          }
        end

        protected

        def description_args
          { prompt: prompts.first }
        end

        private

        def aspect_ratio_to_size(aspect_ratio)
          return nil unless aspect_ratio

          # Map common aspect ratios to size strings
          # Different providers may handle these differently
          case aspect_ratio
          when "16:9"
            "1792x1024"
          when "1:1"
            "1024x1024"
          when "21:9"
            "2048x768"
          when "2:3"
            "896x1152"
          when "3:2"
            "1152x896"
          when "4:5"
            "832x1216"
          when "5:4"
            "1216x832"
          when "9:16"
            "1024x1792"
          when "9:21"
            "768x2048"
          else
            nil
          end
        end
      end
    end
  end
end
