# frozen_string_literal: true

describe Jobs::StreamDiscoverReply do
  subject(:job) { described_class.new }

  fab!(:user)
  fab!(:llm_model)
  fab!(:group)
  fab!(:source_post, :post)
  fab!(:ai_agent) do
    Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
  end
  fab!(:query_rewrite_agent, :ai_agent) do
    Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
  end

  let(:query) { "how do I create a plugin" }
  let(:request_id) { SecureRandom.uuid }
  let(:candidate) do
    {
      "source_ref" => "source_1",
      "topic_id" => source_post.topic_id,
      "post_id" => source_post.id,
      "title" => "Create a Discourse plugin",
      "url" => "/t/create-a-plugin/123/1",
      "excerpt" => "Start with the plugin skeleton.",
      "category" => "Developer",
      "category_id" => 3,
      "topic_replies" => 4,
      "username" => source_post.user.username,
      "name" => source_post.user.name,
      "avatar_template" => source_post.user.avatar_template,
    }
  end
  let(:retrieval_result) do
    DiscourseAi::Discoveries::Retrieval::Result.new(candidates: [candidate])
  end
  let(:retrieval) { instance_double(DiscourseAi::Discoveries::Retrieval) }
  let(:query_rewriter) { instance_double(DiscourseAi::Discoveries::QueryRewriter) }
  let(:synthesis) { instance_double(DiscourseAi::Discoveries::Synthesis) }

  before do
    enable_current_plugin
    SiteSetting.ai_discover_enabled = true
    SiteSetting.ai_discover_agent = ai_agent.id
    SiteSetting.ai_discover_query_rewrite_agent = query_rewrite_agent.id
    SiteSetting.ai_discover_allowed_groups = group.id.to_s
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_semantic_search_enabled = true
    group.add(user)
    DiscourseAi::Discoveries.bind_request(user_id: user.id, request_id:, query:)

    allow(DiscourseAi::Discoveries::QueryRewriter).to receive(:new) do |arguments|
      expect(arguments).to include(user:, ai_agent: query_rewrite_agent, llm_model:)
      expect(arguments[:cancel_manager]).to be_a(DiscourseAi::Completions::CancelManager)
      query_rewriter
    end
    allow(query_rewriter).to receive(:call).with(query).and_return(
      DiscourseAi::Discoveries::QueryRewriter::Result.new(
        keyword_query: query,
        semantic_query: query,
        original_query_locale: user.effective_locale,
      ),
    )
    allow(DiscourseAi::Discoveries::Retrieval).to receive(:new).with(user:).and_return(retrieval)
    allow(retrieval).to receive(:call).and_return(retrieval_result)
    allow(retrieval).to receive(:validated_sources).with(retrieval_result, %w[source_1]).and_return(
      [candidate],
    )
    allow(DiscourseAi::Discoveries::Synthesis).to receive(:new) do |arguments|
      expect(arguments).to include(user:, ai_agent:, llm_model:)
      expect(arguments[:cancel_manager]).to be_a(DiscourseAi::Completions::CancelManager)
      synthesis
    end
    allow(synthesis).to receive(
      :call,
    ) do |query:, candidates:, keyword_query:, original_query_locale:, summary_detail:, related_count:, &stream|
      expect(query).to eq(self.query)
      expect(candidates).to eq([candidate])
      expect(summary_detail).to eq(:balanced)
      expect(related_count).to eq(2)
      stream.call(
        answerable: true,
        source_refs: %w[source_1],
        title: "Create a Discourse plugin",
        answer: "Use the plugin skeleton.",
      )
      DiscourseAi::Discoveries::Synthesis::Result.new(
        answerable: true,
        source_refs: %w[source_1],
        title: "Create a Discourse plugin",
        answer: "Use the plugin skeleton.",
      )
    end
  end

  it "publishes searching, validated sources, streamed answer, and completion events" do
    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(messages.map { |message| message[:phase] }).to eq(
      %w[searching sources answering complete],
    )
    expect(retrieval).to have_received(:call).with(
      query,
      keyword_query: query,
      semantic_query: query,
    )
    expect(messages).to all(include(query:, request_id:))
    expect(messages.second[:sources]).to eq(
      [
        {
          title: candidate["title"],
          url: candidate["url"],
          excerpt: candidate["excerpt"],
          category: candidate["category"],
          category_id: candidate["category_id"],
          topic_replies: candidate["topic_replies"],
          username: candidate["username"],
          name: candidate["name"],
          avatar_template: candidate["avatar_template"],
        },
      ],
    )
    expect(messages.third).to include(
      done: false,
      ai_discover_title: "Create a Discourse plugin",
      ai_discover_reply: "Use the plugin skeleton.",
    )
    expect(messages.last).to include(
      done: true,
      answerable: true,
      ai_discover_title: "Create a Discourse plugin",
      ai_discover_reply: "Use the plugin skeleton.",
    )
    expect(DiscourseAi::Discoveries.cached_result_for(user:, request_id:)).to include(
      "answer" => "Use the plugin skeleton.",
    )
  end

  it "publishes the complete candidate topic list independently of selected sources" do
    other_post = Fabricate(:post)
    other_candidate =
      candidate.merge(
        "source_ref" => "source_2",
        "topic_id" => other_post.topic_id,
        "post_id" => other_post.id,
      )
    duplicate_candidate = other_candidate.merge("source_ref" => "source_3")
    result =
      DiscourseAi::Discoveries::Retrieval::Result.new(
        candidates: [candidate, other_candidate, duplicate_candidate],
      )
    allow(retrieval).to receive(:call).and_return(result)
    allow(retrieval).to receive(:validated_sources).with(result, %w[source_1]).and_return(
      [candidate],
    )
    allow(synthesis).to receive(:call) do |**_, &stream|
      stream.call(
        answerable: true,
        source_refs: %w[source_1],
        title: "Plugin guide",
        answer: "Use the plugin skeleton.",
      )
      DiscourseAi::Discoveries::Synthesis::Result.new(
        answerable: true,
        source_refs: %w[source_1],
        title: "Plugin guide",
        answer: "Use the plugin skeleton.",
      )
    end

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    candidate_topic_ids = [source_post.topic_id, other_post.topic_id]
    expect(messages.find { |message| message[:phase] == "sources" }).to include(
      candidate_topic_ids:,
    )
    expect(messages.last).to include(candidate_topic_ids:)
  end

  it "uses the configured rewrite agent's queries for retrieval" do
    allow(query_rewriter).to receive(:call).with(query).and_return(
      DiscourseAi::Discoveries::QueryRewriter::Result.new(
        keyword_query: "create plugin",
        semantic_query: "how to create a Discourse plugin",
        original_query_locale: "zh_CN",
      ),
    )

    job.execute(user_id: user.id, query:, request_id:)

    expect(retrieval).to have_received(:call).with(
      query,
      keyword_query: "create plugin",
      semantic_query: "how to create a Discourse plugin",
    )
    expect(synthesis).to have_received(:call).with(
      query:,
      candidates: [candidate],
      keyword_query: "create plugin",
      original_query_locale: "zh_CN",
      summary_detail: :balanced,
      related_count: 2,
    )
  end

  it "uses the original query when the configured rewrite agent is unavailable" do
    SiteSetting.ai_discover_query_rewrite_agent = 99_999

    job.execute(user_id: user.id, query:, request_id:)

    expect(DiscourseAi::Discoveries::QueryRewriter).not_to have_received(:new)
    expect(retrieval).to have_received(:call).with(
      query,
      keyword_query: query,
      semantic_query: query,
    )
  end

  it "publishes a supported answer when the model omits the optional title" do
    allow(synthesis).to receive(
      :call,
    ) do |query:, candidates:, keyword_query:, original_query_locale:, summary_detail:, related_count:, &stream|
      expect(query).to eq(self.query)
      expect(keyword_query).to eq(self.query)
      expect(candidates).to eq([candidate])
      expect(summary_detail).to eq(:balanced)
      expect(related_count).to eq(2)
      stream.call(
        answerable: true,
        source_refs: %w[source_1],
        title: "",
        answer: "Use the plugin skeleton.",
      )
      DiscourseAi::Discoveries::Synthesis::Result.new(
        answerable: true,
        source_refs: %w[source_1],
        title: "",
        answer: "Use the plugin skeleton.",
      )
    end

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(messages.last).to include(
      done: true,
      answerable: true,
      ai_discover_title: "",
      ai_discover_reply: "Use the plugin skeleton.",
    )
  end

  it "uses the result settings captured when the search was submitted" do
    SiteSetting.ai_discover_summary_detail = "quiet"
    SiteSetting.ai_discover_related_count = 5
    submitted_settings = DiscourseAi::Discoveries.result_settings
    SiteSetting.ai_discover_summary_detail = "detailed"
    SiteSetting.ai_discover_related_count = 2
    allow(synthesis).to receive(
      :call,
    ) do |query:, candidates:, keyword_query:, original_query_locale:, summary_detail:, related_count:, &stream|
      expect(query).to eq(self.query)
      expect(keyword_query).to eq(self.query)
      expect(candidates).to eq([candidate])
      expect(summary_detail).to eq(:quiet)
      expect(related_count).to eq(5)
      stream.call(
        answerable: true,
        source_refs: %w[source_1],
        title: "",
        answer: "Use the plugin skeleton.",
      )
      DiscourseAi::Discoveries::Synthesis::Result.new(
        answerable: true,
        source_refs: %w[source_1],
        title: "",
        answer: "Use the plugin skeleton.",
      )
    end

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(
            user_id: user.id,
            query:,
            request_id:,
            summary_detail: submitted_settings[:summary_detail].to_s,
            related_count: submitted_settings[:related_count],
          )
        end
        .map(&:data)

    expect(messages.map { |message| message[:phase] }).to eq(
      %w[searching sources answering complete],
    )
    expect(messages.last).to include(
      done: true,
      answerable: true,
      ai_discover_title: "",
      ai_discover_reply: "Use the plugin skeleton.",
    )
    expect(messages.last[:sources]).to be_present
    expect(DiscourseAi::Discoveries.cached_result_for(user:, request_id:)).to include(
      "answer" => "Use the plugin skeleton.",
    )
  end

  it "waits for progressively streamed source references to finish before validating them" do
    second_candidate = candidate.merge("source_ref" => "source_2")
    progressive_result =
      DiscourseAi::Discoveries::Retrieval::Result.new(candidates: [candidate, second_candidate])
    allow(retrieval).to receive(:call).and_return(progressive_result)
    allow(retrieval).to receive(:validated_sources).with(
      progressive_result,
      %w[source_1 source_2],
    ).and_return([candidate, second_candidate])
    allow(synthesis).to receive(
      :call,
    ) do |query:, candidates:, keyword_query:, original_query_locale:, summary_detail:, related_count:, &stream|
      expect(query).to eq(self.query)
      expect(keyword_query).to eq(self.query)
      expect(candidates).to eq([candidate, second_candidate])
      expect(summary_detail).to eq(:balanced)
      expect(related_count).to eq(2)
      stream.call(
        answerable: true,
        source_refs: %w[source_1],
        title: "Create a Discourse plugin",
        answer: "",
      )
      stream.call(
        answerable: true,
        source_refs: %w[source_1 source_2],
        title: "Create a Discourse plugin",
        answer: "Use the two selected discussions.",
      )
      DiscourseAi::Discoveries::Synthesis::Result.new(
        answerable: true,
        source_refs: %w[source_1 source_2],
        title: "Create a Discourse plugin",
        answer: "Use the two selected discussions.",
      )
    end

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(messages.map { |message| message[:phase] }).to eq(
      %w[searching sources answering complete],
    )
    expect(messages.last).to include(
      answerable: true,
      ai_discover_reply: "Use the two selected discussions.",
    )
  end

  it "does not release an answer when the model selects an invalid source" do
    allow(retrieval).to receive(:validated_sources).and_return([])

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(messages.none? { |message| message[:phase] == "answering" }).to eq(true)
    expect(messages.none? { |message| message[:phase] == "sources" }).to eq(true)
    expect(messages.last).to include(
      phase: "complete",
      done: true,
      answerable: false,
      ai_discover_reply: "",
      sources: [],
    )
  end

  it "does not release a placeholder answer" do
    allow(synthesis).to receive(:call).and_return(
      DiscourseAi::Discoveries::Synthesis::Result.new(
        answerable: true,
        source_refs: %w[source_1],
        title: "Plugin guide",
        answer: "true",
      ),
    )

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(messages.map { |message| message[:phase] }).to eq(%w[searching complete])
    expect(messages.last).to include(answerable: false, ai_discover_reply: "", sources: [])
  end

  it "revalidates selected sources before the final answer" do
    allow(retrieval).to receive(:validated_sources).and_return([candidate], [])

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(messages.map { |message| message[:phase] }).to include("sources")
    expect(messages.last).to include(
      phase: "complete",
      done: true,
      answerable: false,
      ai_discover_reply: "",
      sources: [],
    )
    expect(DiscourseAi::Discoveries.cached_result_for(user:, request_id:)).to be_nil
  end

  it "completes without a model call when retrieval has no candidates" do
    empty_result = DiscourseAi::Discoveries::Retrieval::Result.new(candidates: [])
    allow(retrieval).to receive(:call).and_return(empty_result)
    allow(DiscourseAi::Discoveries::Synthesis).to receive(:new)

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(DiscourseAi::Discoveries::Synthesis).not_to have_received(:new)
    expect(messages.last).to include(
      phase: "complete",
      done: true,
      answerable: false,
      ai_discover_reply: "",
      sources: [],
    )
  end

  it "does not run for a user who loses Discoveries access before the job starts" do
    group.remove(user)

    job.execute(user_id: user.id, query:, request_id:)

    expect(retrieval).not_to have_received(:call)
  end

  it "fails quickly when site capacity is unavailable" do
    allow(DiscourseAi::Discoveries).to receive(:admit_request).and_return(false)

    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(retrieval).not_to have_received(:call)
    expect(messages.last).to include(
      done: true,
      error: true,
      error_type: "temporarily_unavailable",
      ai_discover_reply: "",
    )
  end

  it "fails quickly after waiting too long in the queue" do
    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:, queued_at: 3.seconds.ago.to_f)
        end
        .map(&:data)

    expect(retrieval).not_to have_received(:call)
    expect(messages.last).to include(
      done: true,
      error: true,
      error_type: "temporarily_unavailable",
      ai_discover_reply: "",
    )
  end

  it "stops before synthesis when a newer request supersedes it" do
    newer_request_id = SecureRandom.uuid
    allow(retrieval).to receive(:call) do
      DiscourseAi::Discoveries.bind_request(
        user_id: user.id,
        request_id: newer_request_id,
        query: "a newer search",
      )
      retrieval_result
    end
    messages =
      MessageBus
        .track_publish("/discourse-ai/discoveries") do
          job.execute(user_id: user.id, query:, request_id:)
        end
        .map(&:data)

    expect(synthesis).not_to have_received(:call)
    expect(messages.map { |message| message[:phase] }).to eq(%w[searching])
  end
end
