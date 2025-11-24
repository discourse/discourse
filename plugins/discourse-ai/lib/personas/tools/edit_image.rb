# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class EditImage < Tool
        def self.signature
          {
            name: name,
            description: "Edits images based on supplied descriptions and context images",
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

          # Validate that the image URLs exist
          sha1s = image_urls.map { |url| Upload.sha1_from_short_url(url) }.compact
          if sha1s.empty?
            @error = true
            return { prompt: prompt, error: "No valid image URLs provided" }
          end

          # Find available custom image generation tools
          custom_tools = self.class.available_custom_image_tools

          if custom_tools.empty?
            @error = true
            return(
              {
                prompt: prompt,
                error:
                  "No image generation tools configured. Please configure an image generation tool via the admin UI to use this feature.",
              }
            )
          end

          # Use the first available custom image tool
          # Pass image_urls to trigger edit mode in the tool
          tool_class = custom_tools.first

          begin
            tool_params = { prompt: prompt, image_urls: image_urls }

            tool_instance =
              tool_class.new(tool_params, bot_user: bot_user, llm: llm, context: context)

            # Invoke the tool
            tool_instance.invoke { |_progress| }

            # Extract the custom_raw which contains the edited image markdown
            if tool_instance.custom_raw.present?
              # Parse the upload short_url from the markdown
              upload_match = tool_instance.custom_raw.match(%r{!\[.*?\]\((upload://[^)]+)\)})
              if upload_match
                short_url = upload_match[1]
                self.custom_raw = tool_instance.custom_raw
                return { prompt: prompt, url: short_url }
              end
            end

            # If we get here, the tool didn't return a valid result
            @error = true
            { prompt: prompt, error: "Failed to edit image" }
          rescue => e
            @error = e
            Rails.logger.warn("Failed to edit image: #{e}")
            { prompt: prompt, error: e.message }
          end
        end

        protected

        def description_args
          { prompt: prompt }
        end
      end
    end
  end
end
