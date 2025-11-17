# frozen_string_literal: true

class UpdatePostIllustratorSystemPrompt < ActiveRecord::Migration[7.1]
  def up
    # Update the PostIllustrator persona's system_prompt to match the new class definition
    # This ensures the admin UI displays the correct prompt
    persona = DB.query_single("SELECT id FROM ai_personas WHERE id = -21").first

    if persona
      new_system_prompt = <<~PROMPT.strip
        You are an AI assistant that creates images to illustrate posts.

        Your task is to analyze the post content provided in <input></input> tags and generate an appropriate image using your image generation tool.

        Create a creative and descriptive image generation prompt (40 words or less) that captures the essence of the post content, then use your image generation tool to create the image.

        Be creative and ensure the image prompt is clear, detailed, and appropriate for the post content.
      PROMPT

      DB.exec(
        "UPDATE ai_personas SET system_prompt = :system_prompt WHERE id = -21",
        system_prompt: new_system_prompt,
      )
    end
  end

  def down
    persona = DB.query_single("SELECT id FROM ai_personas WHERE id = -21").first

    if persona
      old_system_prompt = <<~PROMPT.strip
        Provide me a StableDiffusion prompt to generate an image that illustrates the following post in 40 words or less, be creative.
        You'll find the post between <input></input> XML tags.

        Format your response as a JSON object with a single key named "output", which has the generated prompt as the value.
        Your output should be in the following format:

        {"output": "xx"}

        Where "xx" is replaced by the generated prompt.
        reply with valid JSON only
      PROMPT

      DB.exec(
        "UPDATE ai_personas SET system_prompt = :system_prompt WHERE id = -21",
        system_prompt: old_system_prompt,
      )
    end
  end
end
