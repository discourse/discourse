# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::ChatThreadTitler do
  subject(:titler) { described_class.new(thread) }

  fab!(:thread, :chat_thread)
  fab!(:chat_message) { Fabricate(:chat_message, thread: thread) }
  fab!(:user)
  fab!(:llm_model)

  let(:chat_thread_titler_persona) do
    AiPersona.find_by(
      id: DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::ChatThreadTitler],
    ) ||
      Fabricate(
        :ai_persona,
        name: "Chat Thread Titler",
        system_prompt: "Generate a title",
        response_format: [{ "key" => "title", "type" => "string" }],
      )
  end

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_chat_thread_title_persona = chat_thread_titler_persona.id
  end

  describe "#suggested_title" do
    it "bails early if thread has no content" do
      empty_thread = Chat::Thread.new

      result = described_class.new(empty_thread).suggested_title

      expect(result).to be_nil
    end

    it "generates a title using the LLM" do
      expected_title = "Discussion about programming"

      result =
        DiscourseAi::Completions::Llm.with_prepared_responses([{ title: expected_title }]) do
          titler.suggested_title
        end

      expect(result).to eq(expected_title)
    end

    it "returns nil when persona is not found" do
      SiteSetting.ai_helper_chat_thread_title_persona = 999_999

      result = titler.suggested_title

      expect(result).to be_nil
    end
  end

  describe "#cleanup" do
    it "picks the first when there are multiple" do
      titles = "The solitary horse\nThe horse etched in gold"
      expected_title = "The solitary horse"

      result = titler.send(:cleanup, titles)

      expect(result).to eq(expected_title)
    end

    it "cleans up double quotes enclosing the whole title" do
      titles = '"The solitary horse"'
      expected_title = "The solitary horse"

      result = titler.send(:cleanup, titles)

      expect(result).to eq(expected_title)
    end

    it "cleans up single quotes enclosing the whole title" do
      titles = "'The solitary horse'"
      expected_title = "The solitary horse"

      result = titler.send(:cleanup, titles)

      expect(result).to eq(expected_title)
    end

    it "leaves quotes in the middle of title" do
      titles = "The 'solitary' horse"
      expected_title = "The 'solitary' horse"

      result = titler.send(:cleanup, titles)

      expect(result).to eq(expected_title)
    end

    it "leaves mismatched quotes intact" do
      titles = %("The solitary horse')

      result = titler.send(:cleanup, titles)

      expect(result).to eq(titles)
    end

    it "truncates long titles" do
      titles = "O cavalo trota pelo campo" + " Pocotó" * 100

      result = titler.send(:cleanup, titles)

      expect(result.size).to be <= 100
    end
  end

  describe "#thread_content" do
    it "returns the chat message and user" do
      expect(titler.send(:thread_content, thread)).to include(chat_message.message)
      expect(titler.send(:thread_content, thread)).to include(chat_message.user.username)
    end
  end
end
