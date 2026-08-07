# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Dialects::OpenAiCompatible do
  before { enable_current_plugin }

  context "when system prompts are disabled" do
    fab!(:model) do
      Fabricate(:vllm_model, vision_enabled: true, provider_params: { disable_system_prompt: true })
    end

    it "merges the system prompt into the first message" do
      system_msg = "This is a system message"
      user_msg = "user message"
      prompt =
        DiscourseAi::Completions::Prompt.new(
          system_msg,
          messages: [{ type: :user, content: user_msg }],
        )

      translated_messages = described_class.new(prompt, model).translate

      expect(translated_messages.length).to eq(1)
      expect(translated_messages).to contain_exactly(
        { role: "user", content: [system_msg, user_msg].join("\n") },
      )
    end

    context "when the prompt has inline images" do
      let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }

      it "produces a valid message" do
        upload = UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
        prompt =
          DiscourseAi::Completions::Prompt.new(
            "You are a bot specializing in image captioning.",
            messages: [
              {
                type: :user,
                content: ["Describe this image in a single sentence.", { upload_id: upload.id }],
              },
            ],
          )
        encoded_upload =
          DiscourseAi::Completions::UploadEncoder.encode(
            upload_ids: [upload.id],
            max_pixels: prompt.max_pixels,
          ).first

        translated_messages = described_class.new(prompt, model).translate

        expect(translated_messages.length).to eq(1)

        # no system message support here
        expected_user_message = {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "You are a bot specializing in image captioning.\nDescribe this image in a single sentence.",
            },
            {
              type: "image_url",
              image_url: {
                url: "data:#{encoded_upload[:mime_type]};base64,#{encoded_upload[:base64]}",
              },
            },
          ],
        }

        expect(translated_messages).to contain_exactly(expected_user_message)
      end
    end
  end

  context "when system prompts are enabled" do
    it "embeds participant names in user message content" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "System instructions",
          messages: [{ type: :user, id: "admin", content: "Who am I?" }],
        )
      model = Fabricate(:samba_nova_model, provider_params: { disable_system_prompt: false })

      expect(described_class.new(prompt, model).translate).to eq(
        [
          { role: "system", content: "System instructions" },
          { role: "user", content: "admin: Who am I?" },
        ],
      )
    end

    it "does not embed protocol IDs from XML tool messages" do
      tool_id = "tool-1"
      model =
        Fabricate(
          :samba_nova_model,
          provider_params: {
            disable_system_prompt: false,
            disable_native_tools: true,
          },
        )
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "System instructions",
          tools: [{ name: "echo", description: "Echo the input" }],
          messages: [
            { type: :user, id: "admin", content: "Echo this" },
            { type: :tool_call, id: tool_id, name: "echo", content: "{}" },
            { type: :tool, id: tool_id, name: "echo", content: '"result"' },
          ],
        )

      translated = described_class.new(prompt, model).translate

      expect(translated.second[:content]).to start_with("admin: ")
      expect(translated.map { |message| message[:content] }.join).not_to include(tool_id)
    end

    it "includes system and user messages separately" do
      system_msg = "This is a system message"
      user_msg = "user message"
      prompt =
        DiscourseAi::Completions::Prompt.new(
          system_msg,
          messages: [{ type: :user, content: user_msg }],
        )

      model = Fabricate(:vllm_model, provider_params: { disable_system_prompt: false })

      translated_messages = described_class.new(prompt, model).translate

      expect(translated_messages.length).to eq(2)
      expect(translated_messages).to contain_exactly(
        { role: "system", content: system_msg },
        { role: "user", content: user_msg },
      )
    end
  end
end
