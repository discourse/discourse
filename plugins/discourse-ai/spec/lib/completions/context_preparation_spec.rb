# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::ContextPreparation do
  fab!(:model) { Fabricate(:llm_model, max_prompt_tokens: 16_000, max_output_tokens: 2000) }
  fab!(:user)

  let(:budget_hint) do
    { type: :user, content: DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT }
  end

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

  def summary_evidence(prompts)
    fragments =
      prompts.map do |request|
        payload = JSON.parse(request.messages.last[:content].lines.last)
        payload.fetch("evidence_fragment")
      end
    JSON.parse(fragments.join)
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
    it "streams and buffers the compression summary" do
      summary = "The codeword is QUARTZ-OTTER-731."
      deltas = ["The codeword is ", "QUARTZ-OTTER-731."]
      body =
        deltas
          .map { |delta| "data: #{{ choices: [{ delta: { content: delta } }] }.to_json}\n\n" }
          .join
      request =
        stub_request(:post, model.url)
          .with { |req| JSON.parse(req.body)["stream"] == true }
          .to_return(status: 200, body: body + "data: [DONE]\n\n")
      prompt = history_prompt

      result = described_class.new(model.to_llm, threshold: 50).prepare!(prompt, user: user)

      expect(result).to eq(:compressed)
      expect(prompt.messages[1][:content]).to eq(
        "<compressed_context>#{summary}</compressed_context>",
      )
      expect(request).to have_been_requested.once
    end

    it "shares execution completion limits across forked contexts without a preparation cap" do
      tracker = DiscourseAi::Completions::TokenUsageTracker.new
      root =
        DiscourseAi::Completions::ExecutionContext.new(
          token_usage_tracker: tracker,
          work_budget: DiscourseAi::Completions::TurnWorkBudget.new(limit: 4000, used: 200),
        )
      state =
        DiscourseAi::Agents::SubagentExecutionState.new(
          execution_context: root,
          root_token_budget: 4000,
        )
      contexts = [root.dup, root.dup]
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(10, "Summary retains QUARTZ-OTTER-731"),
      ) do |canned|
        10.times do |index|
          expect(
            described_class.new(model.to_llm, threshold: 5).prepare!(
              history_prompt(repetitions: 200),
              user: user,
              execution_context: contexts[index % 2],
              subagent_execution_state: state,
            ),
          ).to eq(:compressed)
        end
        expect(canned.completions).to eq(10)
      end
      expect(state.completion_count).to eq(10)
      expect(root.work_budget.used).to eq(200)
    end

    it "summarizes adjacent historical replies in order after removing a budget hint" do
      SiteSetting.authorized_extensions = "jpg|txt"
      model.update!(vision_enabled: true, allowed_attachment_types: ["txt"])
      document_text = "The amber item has been checked."
      document =
        UploadCreator.new(file_from_contents(document_text, "facts.txt"), "facts.txt").create_for(
          user.id,
        )
      image_file = file_from_fixtures("100x100.jpg", "images", "plugins/discourse-ai/spec/fixtures")
      image = UploadCreator.new(image_file, "item.jpg").create_for(user.id)
      image_ref = { upload_id: image.id }
      prompt = history_prompt
      prompt.messages[1][:content] = [
        "Remember these attachments",
        { upload_id: document.id },
        image_ref,
      ]
      private_signature = "opaque provider signature"
      prompt.messages[4][:provider_data] = { signature: private_signature }
      final_reply = "The codeword is ready to use."
      prompt.messages.insert(-2, budget_hint.dup, { type: :model, content: final_reply })
      prompt.push(type: :model, content: "I can recall it for you.")
      original = prompt.messages.deep_dup
      thinking = DiscourseAi::Completions::Thinking.new(message: "Private reasoning")

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [[thinking, "The codeword is ", "QUARTZ-OTTER-731."]],
      ) do |_, _, prompts, options|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        result = described_class.new(llm, threshold: 50).prepare!(prompt, user: user)

        expect(result).to eq(:compressed)
        expect(prompt.messages.map { |message| message[:type] }).to eq(
          %i[system user model user model user model],
        )
        expect(prompt.messages[3][:content]).to include(image_ref)
        expect(prompt.messages.last(2)).to eq(original.last(2))
        expect(prompt.messages[1][:content]).to eq(
          "<compressed_context>The codeword is QUARTZ-OTTER-731.</compressed_context>",
        )
        expect(prompts.first.skip_trim).to eq(true)
        expect(options.first).to include(user: user, feature_name: "context_compression")
        expect(options.first[:max_tokens]).to be_nil
        evidence = summary_evidence(prompts)
        expect(evidence.pluck("type")).to eq(%w[user tool_call tool model model])
        expect(evidence.last(2).pluck("content")).to eq([original[4][:content], final_reply])
        expect(evidence.first["content"]).to match(
          [
            "Remember these attachments",
            a_string_including(document_text),
            "[Retained historical attachment: upload #{image.id}]",
          ],
        )
        expect(evidence.to_json).not_to include(private_signature)
      end
    end

    it "keeps the intact prompt after a soft-threshold summarization failure" do
      [
        "",
        RuntimeError.new("summary failed"),
        Net::ReadTimeout.new,
        "inflated " * 10_000,
      ].each do |response|
        prompt = history_prompt(repetitions: 600)
        prompt.messages.insert(
          -2,
          budget_hint.dup,
          { type: :model, content: "The codeword is ready to use." },
        )
        original = prompt.messages.deep_dup
        DiscourseAi::Completions::Llm.with_prepared_responses([response]) do |_, _, prompts|
          llm = DiscourseAi::Completions::Llm.proxy(model)
          expect(described_class.new(llm, threshold: 20).prepare!(prompt)).to eq(:skipped)
          expect(prompts.size).to eq(1)
          expect(prompt.messages).to eq(original)
          expect(prompt.skip_trim).to eq(true)
        end
      end
    end

    it "logs the triggering post identifiers when compression produces only whitespace" do
      post = Fabricate(:private_message_post)
      prompt = history_prompt(repetitions: 600)
      prompt.topic_id = post.topic_id
      prompt.post_id = post.id
      original = prompt.messages.deep_dup
      logger =
        track_log_messages do
          DiscourseAi::Completions::Llm.with_prepared_responses([" \n\t"]) do
            expect(described_class.new(model.to_llm, threshold: 20).prepare!(prompt)).to eq(
              :skipped,
            )
          end
        end

      expect(logger.warnings).to include(
        "DiscourseAi: context_preparation reason=empty_summary topic_id=#{post.topic_id} post_id=#{post.id} post_number=#{post.post_number}",
      )
      expect(prompt.messages).to eq(original)
    end

    it "keeps the original failure diagnostic when the post lookup is unavailable" do
      post = Fabricate(:private_message_post)
      prompt = history_prompt(repetitions: 600)
      prompt.topic_id = post.topic_id
      prompt.post_id = post.id
      allow(Post).to receive(:where).with(id: post.id).and_raise(
        ActiveRecord::ConnectionNotEstablished,
      )

      logger =
        track_log_messages do
          DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
            expect(described_class.new(model.to_llm, threshold: 20).prepare!(prompt)).to eq(
              :skipped,
            )
          end
        end

      expect(logger.warnings).to include(
        "DiscourseAi: context_preparation reason=empty_summary topic_id=#{post.topic_id} post_id=#{post.id}",
      )
    end

    it "logs summary_not_smaller when compression expands the prompt" do
      prompt = history_prompt(repetitions: 600)
      original = prompt.messages.deep_dup
      logger =
        track_log_messages do
          DiscourseAi::Completions::Llm.with_prepared_responses(["inflated " * 10_000]) do
            expect(described_class.new(model.to_llm, threshold: 20).prepare!(prompt)).to eq(
              :skipped,
            )
          end
        end

      expect(logger.warnings).to include(
        "DiscourseAi: context_preparation reason=summary_not_smaller",
      )
      expect(prompt.messages).to eq(original)
    end

    it "logs summary_over_capacity when a smaller summary still exceeds the answering capacity" do
      prompt = history_prompt(repetitions: 600)
      logger =
        track_log_messages do
          DiscourseAi::Completions::Llm.with_prepared_responses(["inflated " * 2500]) do
            expect(described_class.new(model.to_llm).prepare!(prompt, max_tokens: 14_000)).to eq(
              :compressed,
            )
          end
        end

      expect(logger.warnings).to include(
        "DiscourseAi: context_preparation reason=summary_over_capacity",
        "DiscourseAi: context_preparation reason=history_dropped original_reason=summary_over_capacity dropped_history_messages=4",
      )
      expect_history_dropped(prompt)
    end

    it "drops the oldest history when an empty summary leaves the prompt over capacity" do
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

    it "keeps the newest complete turns and distinct signed replies when dropping history" do
      prompt = history_prompt(repetitions: 4000)
      # Merged consecutive user messages lose their id but are still turn boundaries.
      recent_turn = [
        { type: :user, content: "Also remember AMBER-FOX-42" },
        { type: :tool_call, id: "recent", name: "read", content: '{"arguments":{}}' },
        { type: :tool, id: "recent", name: "read", content: "AMBER-FOX-42 stored" },
        {
          type: :model,
          content: "I stored the new codeword.",
          thinking: "The read completed.",
          thinking_provider_info: {
            anthropic: {
              signature: "stored-signature",
            },
          },
        },
        budget_hint,
        {
          type: :model,
          content: "AMBER-FOX-42 is available for later.",
          thinking: "Confirm the saved codeword.",
          thinking_provider_info: {
            anthropic: {
              signature: "confirmed-signature",
            },
          },
        },
      ]
      prompt.messages.insert(-2, *recent_turn.deep_dup)
      continuation = {
        type: :user,
        content: "Continuation of the assistant response follows.",
        turn_separator: true,
      }

      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(canned.completions).to eq(1)
        expect_history_dropped(
          prompt,
          retained: [*recent_turn[0...-2], continuation, recent_turn.last],
        )
        expect(DiscourseAi::Completions::Prompt.new(messages: prompt.messages)).to eq(prompt)
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

    it "keeps a protected pending call out of the summary when history reused its ID" do
      prompt = history_prompt(repetitions: 10)
      prompt.push(
        type: :tool_call,
        id: "read",
        name: "read",
        content: { arguments: { query: "large argument " * 10_000 } }.to_json,
      )
      original = prompt.messages.deep_dup

      DiscourseAi::Completions::Llm.with_prepared_responses(Array.new(8, "Summary")) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect { described_class.new(llm).prepare!(prompt) }.to raise_error(
          described_class::Error,
          /hard_overflow/,
        )
        expect(canned.completions).to eq(0)
        expect(prompt.messages).to eq(original)
      end
    end

    it "summarizes a completed oversized protected batch that reused a historical ID" do
      prompt = history_prompt(repetitions: 10)
      prompt.push(type: :tool_call, id: "read", name: "read", content: '{"arguments":{}}')
      prompt.push(type: :tool, id: "read", name: "read", content: "Current result " * 10_000)
      expected_batch = JSON.parse(prompt.messages.last(2).to_json)

      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Summary"),
      ) do |_, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)

        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(summary_evidence(prompts).last(2)).to eq(expected_batch)
        expect(prompt.messages.last).to eq(type: :user, content: "What codeword?")
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
          /empty_summary/,
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

    it "covers all evidence beyond eight chunks and the former estimated token allowance" do
      prompt = history_prompt(repetitions: 20_000)
      original_evidence = prompt.messages[1...-1].as_json
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(30, "Summary with QUARTZ-OTTER-731."),
      ) do |canned, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(canned.completions).to be > 8
        estimated_tokens =
          prompts.sum do |request|
            size, capacity, output_reserve = llm.prompt_capacity(request)
            expect(size).to be <= capacity
            size + output_reserve
          end
        expect(estimated_tokens).to be > 64_000
        expect(summary_evidence(prompts)).to eq(original_evidence)
        expect(prompt.messages[1][:content]).to eq(
          "<compressed_context>Summary with QUARTZ-OTTER-731.</compressed_context>",
        )
        expect(prompts.map(&:skip_trim)).to all(eq(true))
      end
    end

    it "associates every compression audit with the originating topic and post" do
      post = Fabricate(:post, user: user)
      prompt = history_prompt(repetitions: 5000)
      prompt.topic_id = post.topic_id
      prompt.post_id = post.id
      response = {
        choices: [{ delta: { content: "Summary retains QUARTZ-OTTER-731." } }],
        usage: {
          prompt_tokens: 100,
          completion_tokens: 20,
        },
      }
      stub_request(:post, model.url)
        .with { |request| JSON.parse(request.body)["stream"] == true }
        .to_return(
          body: "data: #{response.to_json}\n\ndata: [DONE]\n\n",
          headers: {
            "Content-Type" => "text/event-stream",
          },
        )

      tracker = DiscourseAi::Completions::TokenUsageTracker.new
      execution = DiscourseAi::Completions::ExecutionContext.new(token_usage_tracker: tracker)
      expect(
        described_class.new(model.to_llm).prepare!(
          prompt,
          user: user,
          execution_context: execution,
        ),
      ).to eq(:compressed)

      logs = AiApiAuditLog.where(feature_name: "context_compression").order(:id).to_a
      expect(logs.size).to be >= 2
      expect(logs.map { |log| [log.topic_id, log.post_id] }).to all(eq([post.topic_id, post.id]))
      expect(logs.last.prev_log_id).to eq(logs[-2].id)
      expect(tracker.request).to eq(logs.size * 100)
      expect(tracker.response).to eq(logs.size * 20)
      expect(tracker.preparation_tokens).to eq(tracker.total)
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

    it "summarizes oversized completed evidence in order without moving the current requests" do
      prompt = history_prompt(repetitions: 10)
      protected_index = prompt.messages.length - 1
      prompt.push(type: :user, content: "Additional instructions")
      prompt.push(type: :model, content: "I'll read the full record now.")
      prompt.push(type: :model, content: "The next step is a read.")
      prompt.push(type: :tool_call, id: "large", name: "read", content: '{"arguments":{}}')
      prompt.push(type: :tool, id: "large", name: "read", content: "large result " * 7000)
      current_evidence =
        prompt.messages[protected_index..].reject { |message| message[:type] == :user }
      expected_evidence =
        JSON.parse((prompt.messages[1...protected_index] + current_evidence).to_json)

      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Summary of the completed read."),
      ) do |_, _, prompts|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        expect(
          described_class.new(llm).prepare!(prompt, protected_user_index: protected_index),
        ).to eq(:compressed)
        expect(summary_evidence(prompts)).to eq(expected_evidence)
        expect(DiscourseAi::Completions::Prompt.text_only(prompt.messages.last)).to eq(
          "What codeword?\nAdditional instructions",
        )
        expect(DiscourseAi::Completions::Prompt.new(messages: prompt.messages)).to eq(prompt)
      end
    end

    it "protects the latest real request when a saved position is stale or is an internal hint" do
      hint = { type: :user, content: DiscourseAi::Agents::Bot::COMPLETION_LIMIT_FINAL_ANSWER_HINT }
      %i[hint out_of_bounds].each do |invalid_index|
        prompt = history_prompt
        request = prompt.messages.last.dup
        prompt.push(**hint)
        index = invalid_index == :hint ? prompt.messages.length - 1 : prompt.messages.length + 1
        DiscourseAi::Completions::Llm.with_prepared_responses(["The old codeword is saved."]) do
          preparation = described_class.new(model.to_llm, threshold: 50)
          expect(preparation.prepare!(prompt, protected_user_index: index)).to eq(:compressed)
          expect(prompt.messages[preparation.protected_user_index..]).to eq([request, hint])
        end
      end
    end

    it "protects the latest real request rather than an inserted continuation marker" do
      prompt = history_prompt
      # A user can type the same words as a separator; their request is still real.
      prompt.messages.last[:content] = "Continuation of the assistant response follows."
      request = prompt.messages.last
      replies = %w[First Second].map { |text| { type: :model, content: text } }
      replies.each { |reply| prompt.push(**reply) }

      DiscourseAi::Completions::Llm.with_prepared_responses(["The old codeword is saved."]) do
        preparation = described_class.new(model.to_llm, threshold: 50)
        expect(preparation.prepare!(prompt)).to eq(:compressed)
        expect(prompt.messages[preparation.protected_user_index..]).to eq(
          [
            request,
            replies.first,
            { type: :user, content: request[:content], turn_separator: true },
            replies.last,
          ],
        )
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

    it "keeps quota and credit failures visible rather than treating them as a soft fallback" do
      [
        LlmQuotaUsage::QuotaExceededError.new("quota exhausted"),
        LlmCreditAllocation::CreditLimitExceeded.new("credits exhausted"),
      ].each do |error|
        prompt = history_prompt(repetitions: 600)
        original = prompt.messages.deep_dup
        DiscourseAi::Completions::Llm.with_prepared_responses([error]) do
          llm = DiscourseAi::Completions::Llm.proxy(model)
          expect {
            described_class.new(llm, threshold: 20).prepare!(prompt, user: user)
          }.to raise_error(error.class)
          expect(prompt.messages).to eq(original)
        end
      end
    end

    it "falls back intact when completion reservation fails softly and drops history on hard overflow" do
      model.assign_attributes(max_prompt_tokens: 4000, max_output_tokens: 200)
      tracker = DiscourseAi::Completions::TokenUsageTracker.new
      execution = DiscourseAi::Completions::ExecutionContext.new(token_usage_tracker: tracker)
      state =
        DiscourseAi::Agents::SubagentExecutionState.new(
          execution_context: execution,
          root_token_budget: 4000,
          completion_count: DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 1,
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        llm = DiscourseAi::Completions::Llm.proxy(model)
        soft_prompt = history_prompt(repetitions: 60)
        original = soft_prompt.messages.deep_dup
        expect(
          described_class.new(llm, threshold: 20).prepare!(
            soft_prompt,
            subagent_execution_state: state,
          ),
        ).to eq(:skipped)
        expect(soft_prompt.messages).to eq(original)
        expect(soft_prompt.skip_trim).to eq(true)
        hard_prompt = history_prompt(repetitions: 400)
        logger =
          track_log_messages do
            expect(
              described_class.new(llm).prepare!(hard_prompt, subagent_execution_state: state),
            ).to eq(:compressed)
          end
        expect(logger.warnings).to include(
          "DiscourseAi: context_preparation reason=history_dropped original_reason=completion_limit dropped_history_messages=4",
        )
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

    it "accepts a slow successful summary of current-turn evidence without earlier history to drop" do
      result = "Completed action evidence " * 8000
      prompt =
        DiscourseAi::Completions::Prompt.new(
          "System",
          messages: [
            { type: :user, content: "Read and explain the result" },
            { type: :tool_call, id: "read", name: "read", content: "{}" },
            { type: :tool, id: "read", name: "read", content: result },
          ],
        )
      now = 0
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { now }
      summary = "The completed read contains important evidence."
      DiscourseAi::Completions::Llm.with_prepared_responses(Array.new(10, summary)) do |canned|
        llm = model.to_llm
        allow(llm).to receive(:generate).and_wrap_original do |generate, *args, **options, &block|
          response = generate.call(*args, **options, &block)
          now += 91
          response
        end
        expect(described_class.new(llm).prepare!(prompt)).to eq(:compressed)
        expect(canned.completions).to be > 0
        expect(prompt.messages.map { |message| message[:content] }).to eq(
          [
            "System",
            "<compressed_context>#{summary}</compressed_context>",
            DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
            "Read and explain the result",
          ],
        )
        size, capacity = llm.prompt_capacity(prompt)
        expect(size).to be <= capacity
      end
    end

    it "passes cancellation to maintenance and never publishes a cancelled summary" do
      prompt = history_prompt
      original = prompt.messages.deep_dup
      cancel_manager = DiscourseAi::Completions::CancelManager.new
      llm = DiscourseAi::Completions::Llm.proxy(model)
      allow(llm).to receive(:generate) do |_, **options, &block|
        expect(options[:cancel_manager]).to eq(cancel_manager)
        block.call("summary")
        cancel_manager.cancel!
        "summary"
      end
      expect(
        described_class.new(llm, threshold: 50).prepare!(prompt, cancel_manager: cancel_manager),
      ).to eq(:cancelled)
      expect(prompt.messages).to eq(original)
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
