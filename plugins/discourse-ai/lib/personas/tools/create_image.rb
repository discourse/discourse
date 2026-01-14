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
          # Find available custom image generation tools
          custom_tools = self.class.available_custom_image_tools

          if custom_tools.empty?
            @error = true
            return(
              {
                prompts: prompts,
                error:
                  "No image generation tools configured. Please configure an image generation tool via the admin UI to use this feature.",
              }
            )
          end

          # Use the first available custom image tool
          tool_class = custom_tools.first

          # Generate images for each prompt (up to 4)
          max_prompts = prompts.take(4)
          progress = prompts.first
          yield(progress)

          uploads = []
          errors = []

          max_prompts.each do |prompt|
            begin
              # Create tool instance with parameters
              tool_params = { prompt: prompt }

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
                  uploads << { prompt: prompt, upload: upload, url: short_url } if upload
                else
                  # Tool returned custom_raw but not in expected format
                  Rails.logger.error(
                    "CreateImage: Tool #{tool_class.name} returned custom_raw in unexpected format. " \
                      "Expected markdown with upload:// URL. " \
                      "custom_raw preview: #{tool_instance.custom_raw.truncate(200)}",
                  )
                  errors << "Tool returned invalid image format"
                end
              else
                # Tool returned no output
                Rails.logger.warn(
                  "CreateImage: Tool #{tool_class.name} returned no custom_raw output for prompt: #{prompt.truncate(50)}",
                )
                errors << "Tool returned no output"
              end
            rescue => e
              Rails.logger.error(
                "CreateImage: Failed to generate image for prompt '#{prompt.truncate(50)}'. " \
                  "Tool: #{tool_class.name}, Error: #{e.class.name} - #{e.message}",
              )
              errors << e.message
            end
          end

          if uploads.empty?
            @error = true
            return(
              {
                prompts: max_prompts,
                error:
                  "Failed to generate images. #{errors.first || "Please check your image generation tool configuration."}",
              }
            )
          end

          self.custom_raw = <<~RAW

            [grid]
            #{
            uploads
              .map { |item| "![#{item[:prompt].gsub(/\|\'\"/, "")}](#{item[:upload].short_url})" }
              .join(" ")
          }
            [/grid]
          RAW

          { prompts: uploads.map { |item| { prompt: item[:prompt], url: item[:url] } } }
        end

        protected

        def description_args
          { prompt: prompts.first }
        end
      end
    end
  end
end
