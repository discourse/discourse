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

          if image_urls.blank?
            @error = true
            return { prompt: prompt, error: "No valid images provided" }
          end

          # Validate that the image URLs exist
          sha1s = image_urls.map { |url| Upload.sha1_from_short_url(url) }.compact
          if sha1s.empty?
            @error = true
            return { prompt: prompt, error: "No valid image URLs provided" }
          end

          # Check permissions - use context.user (the human) not bot_user
          guardian = Guardian.new(context.user)
          uploads = Upload.where(sha1: sha1s)

          uploads.each do |upload|
            # Check if upload has access control
            if upload.access_control_post_id.present?
              post = Post.find_by(id: upload.access_control_post_id)
              if post && !guardian.can_see?(post)
                @error = true
                return(
                  {
                    prompt: prompt,
                    error:
                      "Access denied: You don't have permission to edit one or more of the provided images",
                  }
                )
              end
            end
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
                { prompt: prompt, url: short_url }
              else
                # Tool returned custom_raw but not in expected format
                Rails.logger.error(
                  "EditImage: Tool #{tool_class.name} returned custom_raw in unexpected format. " \
                    "Expected markdown with upload:// URL. " \
                    "custom_raw preview: #{tool_instance.custom_raw.truncate(200)}",
                )
                @error = true
                { prompt: prompt, error: "Tool returned invalid image format" }
              end
            else
              # Tool returned no output
              Rails.logger.warn(
                "EditImage: Tool #{tool_class.name} returned no custom_raw output. " \
                  "Prompt: #{prompt.truncate(50)}, Image URLs: #{image_urls.length} provided",
              )
              @error = true
              { prompt: prompt, error: "Tool returned no output" }
            end
          rescue => e
            @error = true
            Rails.logger.error(
              "EditImage: Failed to edit image. " \
                "Tool: #{tool_class.name}, Error: #{e.class.name} - #{e.message}. " \
                "Prompt: #{prompt.truncate(50)}, Image URLs: #{image_urls.join(", ")}",
            )
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
