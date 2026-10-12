# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::ContextPreparation do
  fab!(:model) { Fabricate(:llm_model, max_prompt_tokens: 16_000, max_output_tokens: 2000) }
  fab!(:user)

  before { enable_current_plugin }

  def history_prompt(repetitions: 1600, latest: "What codeword?")
    DiscourseAi::Completions::Prompt.new(
      "You are a helpful assistant",
      messages: [
        { type: :user, content: "Remember QUARTZ-OTTER-731" },
        { type: :tool_call, id: "read", name: "read", content: '{"arguments":{}}' },
        {
          type: :tool,
          id: "read",
          name: "read",
          content: "Record: amber item checked. " * repetitions,
        },
        { type: :model, content: "DATA READ" },
        { type: :user, content: latest },
      ],
    )
  end

  def expect_history_dropped(prompt, retained: [])
    expect(prompt.messages.map { |message| message[:type] }).to eq(
      [:system, :user, :model, *retained.map { |message| message[:type] }, :user],
    )
    expect(prompt.messages[1][:content]).to start_with(
      "<compressed_context>#{described_class::HISTORY_DROPPED_NOTICE}",
    )
    expect(prompt.messages[3...-1]).to eq(retained)
    expect(prompt.messages.last[:content]).to eq("What codeword?")
  end

  describe "#prepare!" do
    it "shares maintenance bounds across contexts forked before their first preparation" do
      stub_const(described_class, :MAX_CALLS, 2) do
        root =
          DiscourseAi::Completions::ExecutionContext.new(
            work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000, used: 200),
          )
        first = root.dup
        second = root.dup
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["Summary retains QUARTZ-OTTER-731"] * described_class::MAX_CALLS,
        ) do |canned|
          llm = model.to_llm
          described_class::MAX_CALLS.times do |index|
            preparation = described_class.new(llm, threshold: 5)
            expect(
              preparation.prepare!(
                history_prompt(repetitions: 200),
                user: user,
                execution_context: index.even? ? first : second,
              ),
            ).to eq(:compressed)
            expect(preparation.calls).to eq(index + 1)
          end
          # The prompt still fits hard capacity, so maintenance exhaustion keeps it intact.
          last = history_prompt(repetitions: 200)
          original = last.messages.deep_dup
          expect(
            described_class.new(llm, threshold: 5).prepare!(
              last,
              user: user,
              execution_context: second,
            ),
          ).to eq(:skipped)
          expect(last.messages).to eq(original)
          expect(canned.completions).to eq(described_class::MAX_CALLS)
        end
        expect(root.work_budget.used).to eq(200)
      end
    end

    it "compacts a small message count without summarizing the latest request" do
      prompt = history_prompt
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["The codeword is QUARTZ-OTTER-731."],
      ) do |_, _, prompts, options|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        result = described_class.new(llm, threshold: 50).prepare!(prompt, user: user)

        expect(result).to eq(:compressed)
        expect(prompt.messages.map { |message| message[:type] }).to eq(%i[system user model user])
        expect(prompt.messages.last).to eq(original.last)
        expect(prompts.first.skip_trim).to eq(true)
        expect(options.first).to include(user: user, feature_name: "context_compression")
        evidence = prompts.first.messages.last[:content]
        expect(evidence).to include(original[1][:content], original[3][:content])
        expect(evidence).not_to include(original.last[:content])
      end
    end

    it "keeps the intact prompt after a soft-threshold summarization failure" do
      ["", RuntimeError.new("summary failed"), "inflated " * 10_000].each do |response|
        prompt = history_prompt(repetitions: 600)
        original = prompt.messages.deep_dup
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do
          llm = DiscourseAi::Completions::Llm.proxy(model)
          expect(described_class.new(llm, threshold: 20).prepare!(prompt)).to eq(:skipped)
          expect(prompt.messages).to eq(original)
          expect(prompt.skip_trim).to eq(true)
        end
      end
    end

    it "drops the oldest history when an unusable summary leaves the prompt over capacity" do
      prompt = history_prompt(repetitions: 4000)
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        preparation = described_class.new(llm)

        expect(preparation.prepare!(prompt)).to eq(:compressed)
        expect(canned.completions).to eq(1)
        expect_history_dropped(prompt)
        expect(preparation.protected_user_index).to eq(prompt.messages.length - 1)
      end
    end

    it "keeps the newest complete earlier turns that fit when dropping history" do
      prompt = history_prompt(repetitions: 4000)
      # Merged consecutive user messages lose their id but are still turn boundaries.
      recent_turn = [
        { type: :user, content: "Also remember AMBER-FOX-42" },
        { type: :tool_call, id: "recent", name: "read", content: '{"arguments":{}}' },
        { type: :tool, id: "recent", name: "read", content: "AMBER-FOX-42 stored" },
        { type: :model, content: "Noted." },
      ]
      prompt.messages.insert(-2, *recent_turn.deep_dup)
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect_history_dropped(prompt, retained: recent_turn)
      end
    end

    it "carries a previous checkpoint summary restored behind agent examples" do
      prompt = history_prompt(repetitions: 4000)
      prompt.messages.insert(
        1,
        { type: :user, content: "Example question" },
        { type: :model, content: "Example answer" },
        { type: :user, content: "<compressed_context>Earlier summary</compressed_context>" },
        {
          type: :model,
          content: DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
        },
      )
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect_history_dropped(prompt)
        expect(prompt.messages[1][:content]).to include("Earlier summary")
        expect(prompt.messages.to_s).not_to include("Example question")
        expect(
          DiscourseAi::Completions::PromptMessagesBuilder.compression_checkpoint_index(
            prompt.messages,
          ),
        ).to eq(1)
      end
    end

    it "does not nest notices when dropping history again" do
      prompt = history_prompt(repetitions: 4000)
      previous =
        "#{described_class::HISTORY_DROPPED_NOTICE}#{described_class::PREVIOUS_SUMMARY_LABEL}Earlier summary"
      prompt.messages.insert(
        1,
        { type: :user, content: "<compressed_context>#{previous}</compressed_context>" },
        {
          type: :model,
          content: DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
        },
      )
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(prompt.messages[1][:content]).to eq(
          "<compressed_context>#{previous}</compressed_context>",
        )
      end
    end

    it "prefers recent turns over a previous summary when both do not fit" do
      prompt = history_prompt(repetitions: 4000)
      prompt.messages.insert(
        1,
        {
          type: :user,
          content: "<compressed_context>#{"summary detail " * 4000}</compressed_context>",
        },
        {
          type: :model,
          content: DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
        },
      )
      recent_turn = [
        { type: :user, content: "recent evidence " * 4000, id: "alice" },
        { type: :model, content: "Noted." },
      ]
      prompt.messages.insert(-2, *recent_turn.deep_dup)
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect_history_dropped(prompt, retained: recent_turn)
        expect(prompt.messages[1][:content]).not_to include("summary detail")
      end
    end

    it "keeps the current turn's completed tool batch while dropping earlier history" do
      prompt = history_prompt(repetitions: 4000)
      current_batch = [
        { type: :tool_call, id: "now", name: "read", content: '{"arguments":{}}' },
        { type: :tool, id: "now", name: "read", content: "Side effect completed" },
      ]
      prompt.messages.concat(current_batch.deep_dup)
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)
        preparation = described_class.new(llm)

        expect(preparation.prepare!(prompt)).to eq(:compressed)
        expect(prompt.messages.map { |message| message[:type] }).to eq(
          %i[system user model user tool_call tool],
        )
        expect(prompt.messages.last(2)).to eq(current_batch)
        expect(preparation.protected_user_index).to eq(3)
      end
    end

    it "fails rather than dropping current-turn evidence that cannot fit without history" do
      prompt = history_prompt(repetitions: 10)
      prompt.push(type: :tool_call, id: "large", name: "read", content: '{"arguments":{}}')
      prompt.push(type: :tool, id: "large", name: "read", content: "large result " * 20_000)
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect { described_class.new(llm).prepare!(prompt) }.to raise_error(
          described_class::Error,
          /unusable_summary/,
        )
        expect(prompt.messages).to eq(original)
      end
    end

    it "retains attachments from dropped history when they fit" do
      prompt = history_prompt(repetitions: 4000)
      image = { encoded_upload: { kind: :image, mime_type: "image/png", base64: "image-data" } }
      prompt.messages[1][:content] = ["Remember this image", image]
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(prompt.messages.map { |message| message[:type] }).to eq(
          %i[system user model user model user],
        )
        expect(prompt.messages[3][:content]).to include(image)
        expect(prompt.messages[4][:content]).to eq(described_class::RETAINED_ATTACHMENTS_ACK)
        expect(prompt.messages.last[:content]).to eq("What codeword?")
      end
    end

    it "preserves every fragment of source larger than the model window through bounded merges" do
      prompt = history_prompt(repetitions: 5000)
      original_result = prompt.messages[3][:content]
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Summary with QUARTZ-OTTER-731."),
      ) do |canned, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(canned.completions).to be_between(2, 8)
        fragments =
          prompts.map do |request|
            request.messages.last[:content].split(
              /(?:Conversation evidence|Continuation of evidence):\n/,
              2,
            ).last
          end
        evidence =
          JSON.parse(fragments.map { |fragment| JSON.parse(fragment)["evidence_fragment"] }.join)
        expect(evidence.find { |message| message["type"] == "tool" }["content"]).to eq(
          original_result,
        )
        expect(prompts.map(&:skip_trim)).to all(eq(true))
      end
    end

    it "associates every compression audit with the originating topic and post" do
      post = Fabricate(:post, user: user)
      prompt = history_prompt(repetitions: 5000)
      prompt.topic_id = post.topic_id
      prompt.post_id = post.id
      stub_request(:post, model.url).to_return(
        body: {
          choices: [{ message: { content: "Summary retains QUARTZ-OTTER-731." } }],
          usage: {
            prompt_tokens: 100,
            completion_tokens: 20,
          },
        }.to_json,
        headers: {
          "Content-Type" => "application/json",
        },
      )

      expect(described_class.new(model.to_llm).prepare!(prompt, user: user)).to eq(:compressed)

      logs = AiApiAuditLog.where(feature_name: "context_compression").order(:id).to_a
      expect(logs.size).to be_between(2, described_class::MAX_CALLS)
      expect(logs.map { |log| [log.topic_id, log.post_id] }).to all(eq([post.topic_id, post.id]))
      expect(logs.last.prev_log_id).to eq(logs[-2].id)
    end

    it "bounds maintenance calls and drops hard-overflow history on exhaustion" do
      prompt = history_prompt(repetitions: 5000)
      DiscourseAi::Completions::Llm.with_prepared_responses(["summary"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm, calls: 8).prepare!(prompt)).to eq(:compressed)
        expect_history_dropped(prompt)
        expect(canned.completions).to eq(0)
      end
    end

    it "keeps parallel batches, provider data and thinking intact in the protected tail" do
      prompt = history_prompt
      provider_data = { vllm: { tool_batch_id: "batch-1" } }
      %w[one two].each do |id|
        prompt.push(
          type: :tool_call,
          id: id,
          name: "read",
          content: '{"arguments":{}}',
          provider_data: provider_data,
          thinking: "Inspect evidence",
          thinking_provider_info: {
            anthropic: {
              signature: "signature",
            },
          },
        )
        prompt.push(type: :tool, id: id, name: "read", content: "result #{id}")
      end
      tail = prompt.messages.last(5).deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(["summary"]) do
        llm = DiscourseAi::Completions::Llm.proxy(model)
        described_class.new(llm, threshold: 50).prepare!(prompt)
        expect(prompt.messages.last(5)).to eq(tail)
      end
    end

    it "summarizes complete oversized current-turn evidence but keeps all current user requests" do
      prompt = history_prompt(repetitions: 10)
      prompt.push(type: :user, content: "Additional instructions")
      prompt.push(type: :tool_call, id: "large", name: "read", content: '{"arguments":{}}')
      prompt.push(type: :tool, id: "large", name: "read", content: "large result " * 7000)
      protected_index = 5
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Summary of the completed read."),
      ) do
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(
          described_class.new(llm).prepare!(prompt, protected_user_index: protected_index),
        ).to eq(:compressed)
        expect(DiscourseAi::Completions::Prompt.text_only(prompt.messages.last)).to eq(
          "What codeword?\nAdditional instructions",
        )
        expect(DiscourseAi::Completions::Prompt.new(messages: prompt.messages)).to eq(prompt)
      end
    end

    it "rejects an oversized latest request rather than truncating it" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "Instructions",
          messages: [{ type: :user, content: "request " * 20_000 }],
        )
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect { described_class.new(llm).prepare!(prompt) }.to raise_error(
          described_class::Error,
          /hard_overflow/,
        )
        expect(canned.completions).to eq(0)
        expect(prompt.messages).to eq(original)
      end
    end

    it "keeps applicable quota failures visible rather than treating them as a soft fallback" do
      prompt = history_prompt(repetitions: 600)
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [LlmQuotaUsage::QuotaExceededError.new("quota exhausted")],
      ) do
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect {
          described_class.new(llm, threshold: 20).prepare!(prompt, user: user)
        }.to raise_error(LlmQuotaUsage::QuotaExceededError)
        expect(prompt.messages).to eq(original)
      end
    end

    it "falls back intact when completion reservation fails softly and drops history on hard overflow" do
      tracker = DiscourseAi::Completions::TokenUsageTracker.new
      execution = DiscourseAi::Completions::ExecutionContext.new(token_usage_tracker: tracker)
      state =
        DiscourseAi::Agents::SubagentExecutionState.new(
          execution_context: execution,
          root_token_budget: 4000,
        )
      99.times { state.reserve_completion }
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        soft_prompt = history_prompt(repetitions: 600)
        original = soft_prompt.messages.deep_dup
        expect(
          described_class.new(llm, threshold: 20).prepare!(
            soft_prompt,
            subagent_execution_state: state,
          ),
        ).to eq(:skipped)
        expect(soft_prompt.messages).to eq(original)
        expect(soft_prompt.skip_trim).to eq(true)
        hard_prompt = history_prompt(repetitions: 4000)
        expect(
          described_class.new(llm).prepare!(hard_prompt, subagent_execution_state: state),
        ).to eq(:compressed)
        expect_history_dropped(hard_prompt)
        expect(canned.completions).to eq(0)
        expect(state.reserve_root_final_completion).to eq(true)
      end
    end

    it "includes huge schemas in admission and rejects overflow before any summary call" do
      prompt = history_prompt(repetitions: 10)
      prompt.tools = [{ name: "huge", description: "schema description " * 10_000, parameters: [] }]
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect { described_class.new(llm).prepare!(prompt) }.to raise_error(
          described_class::Error,
          /hard_overflow/,
        )
        expect(canned.completions).to eq(0)
      end
    end

    it "retains small visual history without an unnecessary summary" do
      prompt = history_prompt(repetitions: 10)
      prompt.messages[1][:content] = [
        "Remember this image",
        { encoded_upload: { kind: :image, mime_type: "image/png", base64: "image-data" } },
      ]
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm, threshold: 80).prepare!(prompt)).to eq(:not_needed)
        expect(prompt.messages).to eq(original)
        expect(canned.completions).to eq(0)
      end
    end

    it "uses expanded document evidence rather than measuring only the upload marker" do
      model.update!(allowed_attachment_types: ["txt"])
      prompt = history_prompt(repetitions: 10)
      text = "Document facts include QUARTZ-OTTER-731. " * 700
      prompt.messages[1][:content] = [
        "Remember these facts",
        {
          encoded_upload: {
            kind: :document,
            filename: "facts.txt",
            mime_type: "text/plain",
            base64: Base64.strict_encode64(text),
            text: text,
          },
        },
      ]
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["The document contains QUARTZ-OTTER-731."],
      ) do |_, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm, threshold: 20).prepare!(prompt)).to eq(:compressed)
        expect(prompts.first.messages.last[:content]).to include(text)
      end
    end

    it "rejects malformed PDF data rather than silently dropping it" do
      model.update!(allowed_attachment_types: ["pdf"])
      prompt = history_prompt(repetitions: 10)
      prompt.messages.last[:content] = [
        "Read this PDF",
        {
          encoded_upload: {
            kind: :document,
            filename: "facts.pdf",
            mime_type: "application/pdf",
            base64: "pdf-data",
          },
        },
      ]
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect { described_class.new(llm).prepare!(prompt) }.to raise_error(
          described_class::Error,
          /invalid_document/,
        )
        expect(canned.completions).to eq(0)
      end
    end

    it "leaves a late maintenance response unpublished after the preparation deadline" do
      prompt = history_prompt(repetitions: 600)
      original = prompt.messages.deep_dup
      now = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { now }
      DiscourseAi::Completions::Llm.with_prepared_responses(["Late summary."]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        allow(llm).to receive(:generate).and_wrap_original do |generate, *args, **options|
          result = generate.call(*args, **options)
          now = 91
          result
        end
        expect(described_class.new(llm, threshold: 20).prepare!(prompt)).to eq(:skipped)
        expect(canned.completions).to eq(1)
        expect(prompt.messages).to eq(original)
      end
    end

    it "passes cancellation to maintenance and never publishes a cancelled summary" do
      prompt = history_prompt
      original = prompt.messages.deep_dup
      cancel_manager = DiscourseAi::Completions::CancelManager.new
      llm = DiscourseAi::Completions::Llm.proxy(model)
      allow(llm).to receive(:generate) do |_, **options|
        expect(options[:cancel_manager]).to eq(cancel_manager)
        cancel_manager.cancel!
        "summary"
      end
      expect(
        described_class.new(llm, threshold: 50).prepare!(prompt, cancel_manager: cancel_manager),
      ).to eq(:cancelled)
      expect(prompt.messages).to eq(original)
    end

    it "charges only maintenance time, not ordinary tool work, and shares the allowance across preparations" do
      now = 0.0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { now }
      execution = DiscourseAi::Completions::ExecutionContext.new
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Concise evidence"),
      ) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        preparation = described_class.new(llm, threshold: 20, calls: 7)
        now = 120.0
        expect(
          preparation.prepare!(history_prompt(repetitions: 600), execution_context: execution),
        ).to eq(:compressed)
        expect(preparation.calls).to eq(8)
        expect(preparation.elapsed_seconds).to eq(0)

        child_preparation = described_class.new(llm, threshold: 20)
        prompt = history_prompt(repetitions: 4000)
        expect(child_preparation.prepare!(prompt, execution_context: execution)).to eq(:compressed)
        expect(child_preparation.calls).to eq(8)
        expect(child_preparation.spent_tokens).to eq(preparation.spent_tokens)
        expect_history_dropped(prompt)
        expect(canned.completions).to eq(1)
      end
    end

    it "skips checkpoint-only maintenance when the protected current request is above the soft threshold" do
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "System",
          messages: [
            {
              type: :user,
              content: "<compressed_context>Existing concise summary</compressed_context>",
            },
            {
              type: :model,
              content: DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
            },
            { type: :user, content: "Current request " * 600 },
          ],
        )
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm, threshold: 10).prepare!(prompt)).to eq(:not_needed)
        expect(prompt.messages).to eq(original)
        expect(canned.completions).to eq(0)
      end
    end

    it "keeps unresolved nil-ID calls instead of considering them completed" do
      prompt = history_prompt(repetitions: 10)
      prompt.messages.concat(
        [
          { type: :tool_call, name: "read", content: "{}" },
          { type: :tool, name: "read", content: "Huge pending result " * 10_000 },
        ],
      )
      original = prompt.messages.deep_dup
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect { described_class.new(llm).prepare!(prompt) }.to raise_error(
          described_class::Error,
          /hard_overflow/,
        )
        expect(prompt.messages).to eq(original)
        expect(canned.completions).to eq(0)
      end
    end

    it "packs escaped evidence using complete rendered requests and preserves exact literals" do
      literal = "QUARTZ-OTTER-731"
      prompt = history_prompt(repetitions: 10)
      evidence = ("\\\"Record #{literal}\"\\\n" * 1800)
      prompt.messages[3][:content] = evidence
      prompt.messages[2][:provider_data] = { private_signature: "opaque provider metadata" }
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Remember #{literal}"),
      ) do |_, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm, threshold: 20).prepare!(prompt)).to eq(:compressed)
        fragments =
          prompts.map do |request|
            size, capacity = llm.prompt_capacity(request, max_tokens: 2000)
            expect(size).to be <= capacity
            JSON.parse(
              request.messages.last[:content].split(
                /(?:Conversation evidence|Continuation of evidence):\n/,
                2,
              ).last,
            )[
              "evidence_fragment"
            ]
          end
        reconstructed = JSON.parse(fragments.join)
        expect(reconstructed.find { |message| message["type"] == "tool" }["content"]).to eq(
          evidence,
        )
        expect(fragments.join).not_to include("opaque provider metadata")
        expect(prompt.messages[1][:content]).to include(literal)
      end
    end

    it "compacts textual evidence while retaining prior images verbatim" do
      model.update!(vision_enabled: true)
      prompt = history_prompt(repetitions: 4000)
      image = {
        encoded_upload: {
          kind: :image,
          mime_type: "image/png",
          base64:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/wcAAgEB/awxUE0AAAAASUVORK5CYII=",
        },
      }
      prompt.messages[1][:content] = ["Remember QUARTZ-OTTER-731 and this image", image]
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "The codeword is QUARTZ-OTTER-731 with a retained image."),
      ) do |_, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(prompt.messages.flat_map { |message| Array(message[:content]) }).to include(image)
        expect(prompts.map(&:messages).to_s).not_to include(image[:encoded_upload][:base64])
        size, capacity = llm.prompt_capacity(prompt)
        expect(size).to be <= capacity
      end
    end

    it "retains native PDF evidence while compacting the surrounding textual history" do
      model.update!(max_prompt_tokens: 24_000, allowed_attachment_types: ["pdf"])
      pdf = file_from_fixtures("2-page.pdf", "rag", "plugins/discourse-ai/spec/fixtures")
      attachment = {
        encoded_upload: {
          kind: :document,
          filename: "2-page.pdf",
          mime_type: "application/pdf",
          base64: Base64.strict_encode64(File.binread(pdf.path)),
        },
      }
      prompt = history_prompt(repetitions: 5000)
      prompt.messages[1][:content] = ["Remember this original PDF and the codeword", attachment]
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "The original PDF is retained with the codeword and read evidence."),
      ) do |_, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(prompt.messages.flat_map { |message| Array(message[:content]) }).to include(
          attachment,
        )
        expect(prompts.map(&:messages).to_s).not_to include(attachment[:encoded_upload][:base64])
        size, capacity = llm.prompt_capacity(prompt)
        expect(size).to be < capacity
      end
    end
  end
end
