# frozen_string_literal: true

module DiscourseAi
  module Personas
    class PostIllustrator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are an AI assistant that creates images to illustrate posts.

          Your task is to analyze the post content provided in <input></input> tags and generate an appropriate image using your image generation tool.

          Create a creative and descriptive image generation prompt (40 words or less) that captures the essence of the post content, then use your image generation tool to create the image.

          Be creative and ensure the image prompt is clear, detailed, and appropriate for the post content.
        PROMPT
      end

      def tools
        @tools ||=
          begin
            image_tool_ids = AiTool.where(enabled: true, is_image_generation_tool: true).pluck(:id)

            image_tool_ids.map do |tool_id|
              DiscourseAi::Personas::Tools::Custom.class_instance(tool_id)
            end
          end
      end

      def force_tool_use
        tools
      end

      def forced_tool_count
        1
      end
    end
  end
end
