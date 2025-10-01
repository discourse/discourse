#frozen_string_literal: true

class TestPersona < DiscourseAi::Personas::Persona
  def tools
    [
      DiscourseAi::Personas::Tools::ListTags,
      DiscourseAi::Personas::Tools::Search,
      DiscourseAi::Personas::Tools::Image,
    ]
  end

  def system_prompt
    <<~PROMPT
      {site_url}
      {site_title}
      {site_description}
      {participants}
      {time}
      {resource_url}
      {inferred_concepts}
    PROMPT
  end
end

RSpec.describe DiscourseAi::Personas::Persona do
  let(:persona) { TestPersona.new }

  let(:topic_with_users) do
    topic = Topic.new
    topic.allowed_users = [User.new(username: "joe"), User.new(username: "jane")]
    topic
  end

  let(:resource_url) { "https://path-to-resource" }
  let(:inferred_concepts) { %w[bulbassaur charmander squirtle].join(", ") }

  let(:context) do
    DiscourseAi::Personas::BotContext.new(
      site_url: Discourse.base_url,
      site_title: "test site title",
      site_description: "test site description",
      time: Time.zone.now,
      participants: topic_with_users.allowed_users.map(&:username).join(", "),
      resource_url: resource_url,
      inferred_concepts: inferred_concepts,
    )
  end

  fab!(:admin)
  fab!(:user)
  fab!(:upload)

  before { enable_current_plugin }

  after do
    # we are rolling back transactions so we can create poison cache
    AiPersona.persona_cache.flush!
  end

  it "renders the system prompt" do
    freeze_time

    rendered = persona.craft_prompt(context)
    system_message = rendered.messages.first[:content]

    expect(system_message).to include(Discourse.base_url)
    expect(system_message).to include("test site title")
    expect(system_message).to include("test site description")
    expect(system_message).to include("joe, jane")
    expect(system_message).to include(Time.zone.now.to_s)
    expect(system_message).to include(resource_url)
    expect(system_message).to include(inferred_concepts)

    tools = rendered.tools

    expect(tools.find { |t| t.name == "search" }).to be_present
    expect(tools.find { |t| t.name == "tags" }).to be_present

    # needs to be configured so it is not available
    expect(tools.find { |t| t.name == "image" }).to be_nil
  end

  it "can parse string that are wrapped in quotes" do
    SiteSetting.ai_stability_api_key = "123"

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "image",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          prompts: ["cat oil painting", "big car"],
          aspect_ratio: "16:9",
        },
      )

    tool_instance =
      DiscourseAi::Personas::Artist.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(tool_instance.parameters[:prompts]).to eq(["cat oil painting", "big car"])
    expect(tool_instance.parameters[:aspect_ratio]).to eq("16:9")
  end

  it "enforces enums" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          status: "cow",
          foo: "bar",
        },
      )

    tool_instance =
      DiscourseAi::Personas::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(tool_instance.parameters.key?(:status)).to eq(false)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          status: "open",
          foo: "bar",
        },
      )

    tool_instance =
      DiscourseAi::Personas::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(tool_instance.parameters[:status]).to eq("open")
  end

  it "can coerce integers" do
    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "search",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          max_posts: "3.2",
          search_query: "hello world",
          foo: "bar",
        },
      )

    search =
      DiscourseAi::Personas::General.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)

    expect(search.parameters[:max_posts]).to eq(3)
    expect(search.parameters[:search_query]).to eq("hello world")
    expect(search.parameters.key?(:foo)).to eq(false)
  end

  it "can correctly parse arrays in tools" do
    SiteSetting.ai_openai_api_key = "123"

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        name: "dall_e",
        id: "call_JtYQMful5QKqw97XFsHzPweB",
        parameters: {
          prompts: ["cat oil painting", "big car"],
        },
      )

    tool_instance =
      DiscourseAi::Personas::DallE3.new.find_tool(tool_call, bot_user: nil, llm: nil, context: nil)
    expect(tool_instance.parameters[:prompts]).to eq(["cat oil painting", "big car"])
  end

  describe "custom personas" do
    it "is able to find custom personas" do
      Group.refresh_automatic_groups!

      # define an ai persona everyone can see
      persona =
        AiPersona.create!(
          name: "zzzpun_bot",
          description: "you write puns",
          system_prompt: "you are pun bot",
          tools: ["Image"],
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        )

      custom_persona = DiscourseAi::Personas::Persona.all(user: user).last
      expect(custom_persona.name).to eq("zzzpun_bot")
      expect(custom_persona.description).to eq("you write puns")

      instance = custom_persona.new
      expect(instance.tools).to eq([DiscourseAi::Personas::Tools::Image])
      expect(instance.craft_prompt(context).messages.first[:content]).to eq("you are pun bot")

      # should update
      persona.update!(name: "zzzpun_bot2")
      custom_persona = DiscourseAi::Personas::Persona.all(user: user).last
      expect(custom_persona.name).to eq("zzzpun_bot2")

      # can be disabled
      persona.update!(enabled: false)
      last_persona = DiscourseAi::Personas::Persona.all(user: user).last
      expect(last_persona.name).not_to eq("zzzpun_bot2")

      persona.update!(enabled: true)
      # no groups have access
      persona.update!(allowed_group_ids: [])

      last_persona = DiscourseAi::Personas::Persona.all(user: user).last
      expect(last_persona.name).not_to eq("zzzpun_bot2")
    end
  end

  describe "available personas" do
    it "includes all personas by default" do
      Group.refresh_automatic_groups!

      # must be enabled to see it
      SiteSetting.ai_stability_api_key = "abc"
      SiteSetting.ai_google_custom_search_api_key = "abc"
      SiteSetting.ai_google_custom_search_cx = "abc123"

      # should be ordered by priority and then alpha
      expect(DiscourseAi::Personas::Persona.all(user: user).map(&:superclass)).to contain_exactly(
        DiscourseAi::Personas::General,
        DiscourseAi::Personas::Artist,
        DiscourseAi::Personas::Creative,
        DiscourseAi::Personas::DiscourseHelper,
        DiscourseAi::Personas::Discover,
        DiscourseAi::Personas::GithubHelper,
        DiscourseAi::Personas::Researcher,
        DiscourseAi::Personas::SettingsExplorer,
        DiscourseAi::Personas::SqlHelper,
      )

      # it should allow staff access to WebArtifactCreator
      expect(DiscourseAi::Personas::Persona.all(user: admin).map(&:superclass)).to contain_exactly(
        DiscourseAi::Personas::General,
        DiscourseAi::Personas::Artist,
        DiscourseAi::Personas::Creative,
        DiscourseAi::Personas::DiscourseHelper,
        DiscourseAi::Personas::Discover,
        DiscourseAi::Personas::GithubHelper,
        DiscourseAi::Personas::Researcher,
        DiscourseAi::Personas::SettingsExplorer,
        DiscourseAi::Personas::SqlHelper,
        DiscourseAi::Personas::WebArtifactCreator,
      )

      # omits personas if key is missing
      SiteSetting.ai_stability_api_key = ""
      SiteSetting.ai_google_custom_search_api_key = ""
      SiteSetting.ai_artifact_security = "disabled"

      expect(DiscourseAi::Personas::Persona.all(user: admin).map(&:superclass)).to contain_exactly(
        DiscourseAi::Personas::General,
        DiscourseAi::Personas::SqlHelper,
        DiscourseAi::Personas::SettingsExplorer,
        DiscourseAi::Personas::Creative,
        DiscourseAi::Personas::DiscourseHelper,
        DiscourseAi::Personas::Discover,
        DiscourseAi::Personas::GithubHelper,
      )

      AiPersona.find(
        DiscourseAi::Personas::Persona.system_personas[DiscourseAi::Personas::General],
      ).update!(enabled: false)

      expect(DiscourseAi::Personas::Persona.all(user: user).map(&:superclass)).to contain_exactly(
        DiscourseAi::Personas::SqlHelper,
        DiscourseAi::Personas::SettingsExplorer,
        DiscourseAi::Personas::Creative,
        DiscourseAi::Personas::DiscourseHelper,
        DiscourseAi::Personas::Discover,
        DiscourseAi::Personas::GithubHelper,
      )
    end
  end

  describe "#craft_prompt" do
    fab!(:vector_def) { Fabricate(:embedding_definition) }

    before do
      Group.refresh_automatic_groups!
      SiteSetting.ai_embeddings_selected_model = vector_def.id
      SiteSetting.ai_embeddings_enabled = true
    end

    let(:ai_persona) { DiscourseAi::Personas::Persona.all(user: user).first.new }

    let(:with_cc) do
      context.messages = [{ content: "Tell me the time", type: :user }]
      context
    end

    context "when a persona has no uploads" do
      it "doesn't include RAG guidance" do
        guidance_fragment =
          "The following texts will give you additional guidance to elaborate a response."

        expect(ai_persona.craft_prompt(with_cc).messages.first[:content]).not_to include(
          guidance_fragment,
        )
      end
    end

    context "when RAG is running with a question consolidator" do
      let(:consolidated_question) { "what is the time in france?" }

      fab!(:llm_model) { Fabricate(:fake_model) }

      fab!(:custom_ai_persona) do
        Fabricate(
          :ai_persona,
          name: "custom",
          rag_conversation_chunks: 3,
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          question_consolidator_llm_id: llm_model.id,
        )
      end

      before do
        context_embedding = vector_def.dimensions.times.map { rand(-1.0...1.0) }
        EmbeddingsGenerationStubs.hugging_face_service(consolidated_question, context_embedding)

        UploadReference.ensure_exist!(target: custom_ai_persona, upload_ids: [upload.id])
      end

      it "will run the question consolidator" do
        custom_persona =
          DiscourseAi::Personas::Persona.find_by(id: custom_ai_persona.id, user: user).new

        # this means that we will consolidate
        context.messages = [
          { content: "Tell me the time", type: :user },
          { content: "the time is 1", type: :model },
          { content: "in france?", type: :user },
        ]

        DiscourseAi::Completions::Endpoints::Fake.with_fake_content(consolidated_question) do
          custom_persona.craft_prompt(context).messages.first[:content]
        end

        message =
          DiscourseAi::Completions::Endpoints::Fake.last_call[:dialect].prompt.messages.last[
            :content
          ]
        expect(message).to include("Tell me the time")
        expect(message).to include("the time is 1")
        expect(message).to include("in france?")
      end

      context "when there are messages with uploads" do
        let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
        let(:image_upload) do
          UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
        end

        it "the question consolidator works" do
          custom_persona =
            DiscourseAi::Personas::Persona.find_by(id: custom_ai_persona.id, user: user).new

          context.messages = [
            { content: "Tell me the time", type: :user },
            { content: "the time is 1", type: :model },
            { content: ["in france?", { upload_id: image_upload.id }], type: :user },
          ]

          DiscourseAi::Completions::Endpoints::Fake.with_fake_content(consolidated_question) do
            custom_persona.craft_prompt(context).messages.first[:content]
          end

          message =
            DiscourseAi::Completions::Endpoints::Fake.last_call[:dialect].prompt.messages.last[
              :content
            ]
          expect(message).to include("Tell me the time")
          expect(message).to include("the time is 1")
          expect(message).to include("in france?")
        end
      end
    end

    context "when a persona has RAG uploads" do
      let(:embedding_value) { 0.04381 }
      let(:prompt_cc_embeddings) { [embedding_value] * vector_def.dimensions }

      def stub_fragments(fragment_count, persona: ai_persona)
        schema = DiscourseAi::Embeddings::Schema.for(RagDocumentFragment)

        fragment_count.times do |i|
          fragment =
            Fabricate(
              :rag_document_fragment,
              fragment: "fragment-n#{i}",
              target_id: persona.id,
              target_type: "AiPersona",
              upload: upload,
            )

          # Similarity is determined left-to-right.
          embeddings = [embedding_value + "0.000#{i}".to_f] * vector_def.dimensions

          schema.store(fragment, embeddings, "test")
        end
      end

      before do
        stored_ai_persona = AiPersona.find(ai_persona.id)
        UploadReference.ensure_exist!(target: stored_ai_persona, upload_ids: [upload.id])

        EmbeddingsGenerationStubs.hugging_face_service(
          with_cc.messages.dig(0, :content),
          prompt_cc_embeddings,
        )
      end

      context "when persona allows for less fragments" do
        it "will only pick 3 fragments" do
          custom_ai_persona =
            Fabricate(
              :ai_persona,
              name: "custom",
              rag_conversation_chunks: 3,
              allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
            )

          stub_fragments(3, persona: custom_ai_persona)

          UploadReference.ensure_exist!(target: custom_ai_persona, upload_ids: [upload.id])

          custom_persona =
            DiscourseAi::Personas::Persona.find_by(id: custom_ai_persona.id, user: user).new

          expect(custom_persona.class.rag_conversation_chunks).to eq(3)

          crafted_system_prompt = custom_persona.craft_prompt(with_cc).messages.first[:content]

          expect(crafted_system_prompt).to include("fragment-n0")
          expect(crafted_system_prompt).to include("fragment-n1")
          expect(crafted_system_prompt).to include("fragment-n2")
          expect(crafted_system_prompt).not_to include("fragment-n3")
        end
      end

      context "when the reranker is available" do
        before do
          SiteSetting.ai_hugging_face_tei_reranker_endpoint = "https://test.reranker.com"
          stub_fragments(15)
        end

        it "uses the re-ranker to reorder the fragments and pick the top 10 candidates" do
          skip "This test is flaky needs to be investigated ordering does not come back as expected"
          # The re-ranker reverses the similarity search, but return less results
          # to act as a limit for test-purposes.
          expected_reranked = (4..14).to_a.reverse.map { |idx| { index: idx } }

          WebMock.stub_request(:post, "https://test.reranker.com/rerank").to_return(
            status: 200,
            body: JSON.dump(expected_reranked),
          )

          crafted_system_prompt = ai_persona.craft_prompt(with_cc).messages.first[:content]

          expect(crafted_system_prompt).to include("fragment-n14")
          expect(crafted_system_prompt).to include("fragment-n13")
          expect(crafted_system_prompt).to include("fragment-n12")
          expect(crafted_system_prompt).not_to include("fragment-n4") # Fragment #11 not included
        end
      end

      context "when the reranker is not available" do
        before { stub_fragments(10) }

        it "picks the first 10 candidates from the similarity search" do
          crafted_system_prompt = ai_persona.craft_prompt(with_cc).messages.first[:content]

          expect(crafted_system_prompt).to include("fragment-n0")
          expect(crafted_system_prompt).to include("fragment-n1")
          expect(crafted_system_prompt).to include("fragment-n2")

          expect(crafted_system_prompt).not_to include("fragment-n10") # Fragment #10 not included
        end
      end

      context "when the persona has examples" do
        fab!(:examples_persona) do
          Fabricate(
            :ai_persona,
            examples: [["User message", "assistant response"]],
            allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          )
        end

        it "includes them before the context messages" do
          custom_persona =
            DiscourseAi::Personas::Persona.find_by(id: examples_persona.id, user: user).new

          post_system_prompt_msgs = custom_persona.craft_prompt(with_cc).messages.last(3)

          expect(post_system_prompt_msgs).to contain_exactly(
            { content: "User message", type: :user },
            { content: "assistant response", type: :model },
            { content: "Tell me the time", type: :user },
          )
        end
      end
    end
  end
end
