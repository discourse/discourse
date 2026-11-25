# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::StreamReplyCustomToolsSession do
  fab!(:admin)
  fab!(:llm) { Fabricate(:llm_model, name: "fake_llm", provider: "fake") }
  fab!(:ai_agent) do
    agent =
      Fabricate(
        :ai_agent,
        allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
        default_llm_id: llm.id,
        allow_personal_messages: true,
        max_turn_tokens: 5000,
        compression_threshold: 80,
      )
    agent.create_user!
    agent
  end

  let(:custom_tools) do
    [
      {
        name: "client_tool",
        description: "A test tool",
        parameters: [{ name: "input", description: "input value", type: "string", required: true }],
      },
    ]
  end

  include_context "with AI bot enabled"

  before { SiteSetting.ai_bot_allowed_groups = "10" }

  def build_session(
    query: "test question",
    resume_token: nil,
    tool_results: nil,
    topic: nil,
    current_user: admin,
    custom_tools: self.custom_tools
  )
    described_class.new(
      agent: ai_agent,
      llm_model: resume_token ? nil : ai_agent.default_llm,
      user: admin,
      topic: topic,
      query: query,
      custom_instructions: nil,
      current_user: current_user,
      custom_tools: custom_tools,
      resume_token: resume_token,
      tool_results: tool_results,
    )
  end

  def collect_events(session)
    events = []
    session.run { |type, data| events << [type, data] }
    events
  end

  describe "custom tool resume" do
    it "accepts a corrected result batch on the same token and debits each result once" do
      read_call, confirm_call, next_call =
        %w[read confirm next].map do |id|
          DiscourseAi::Completions::ToolCall.new(id: id, name: "client_tool", parameters: {})
        end
      read_result = { tool_call_id: read_call.id, content: "Inventory read" }
      confirm_result = { tool_call_id: confirm_call.id, content: "Inventory confirmed" }
      answer = "The inventory is ready."

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [[read_call, confirm_call], next_call, answer, "Inventory"],
      ) do |canned, _, prompts|
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        key = described_class.redis_key(token)
        original_state = Discourse.redis.get(key)
        initial_work = JSON.parse(original_state).dig("work_budget", "used")
        topic = Topic.find(events.find { |type, _| type == :context }.last[:topic_id])
        Discourse.redis.expire(key, 2.minutes.to_i)
        ttl_before_rejection = Discourse.redis.pttl(key)

        invalid_batches = [
          [read_result, confirm_result.merge(tool_call_id: "comfirm")],
          [read_result, confirm_result.except(:content)],
        ]
        invalid_batches.each do |batch|
          expect {
            collect_events(build_session(resume_token: token, tool_results: batch))
          }.to raise_error(described_class::InvalidToolResults)
          expect(Discourse.redis.get(key)).to eq(original_state)
          expect(Discourse.redis.pttl(key)).to be_between(1, ttl_before_rejection)
          expect(canned.completions).to eq(1)
          expect(topic.posts.count).to eq(1)
        end

        events =
          collect_events(
            build_session(resume_token: token, tool_results: [read_result, confirm_result]),
          )
        next_token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        expect(next_token).not_to eq(token)
        expect(described_class.resume_state_exists?(token)).to eq(false)
        expect(canned.completions).to eq(2)
        expect(prompts.last.messages.select { |message| message[:type] == :tool }).to match(
          [
            a_hash_including(id: read_call.id, content: read_result[:content]),
            a_hash_including(id: confirm_call.id, content: confirm_result[:content]),
          ],
        )
        tokenizer = llm.to_llm.tokenizer
        output = DiscourseAi::Completions::GeneratedOutput.new
        output << next_call
        work =
          JSON.parse(Discourse.redis.get(described_class.redis_key(next_token))).fetch(
            "work_budget",
          )
        expect(work["used"]).to eq(
          initial_work + tokenizer.size(read_result[:content]) +
            tokenizer.size(confirm_result[:content]) + output.size(tokenizer),
        )

        final_results = [{ tool_call_id: next_call.id, content: "Next check completed" }]
        collect_events(build_session(resume_token: next_token, tool_results: final_results))
        expect {
          collect_events(build_session(resume_token: next_token, tool_results: final_results))
        }.to raise_error(described_class::ResumeTokenNotFound)
        expect(topic.posts.order(:post_number).pluck(:raw)).to eq(["test question", answer])
        expect(canned.completions).to eq(4)
      end
    end

    it "rejects duplicate result IDs without replacing or consuming the pending batch" do
      call = DiscourseAi::Completions::ToolCall.new(id: "read", name: "client_tool", parameters: {})
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [call, "Inventory is ready", "Inventory"],
      ) do |canned|
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        key = described_class.redis_key(token)
        original_state = Discourse.redis.get(key)

        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [
                { tool_call_id: call.id, content: "First outcome" },
                { id: call.id, content: "Conflicting outcome" },
              ],
            ),
          )
        }.to raise_error(described_class::InvalidToolResults)
        expect(Discourse.redis.get(key)).to eq(original_state)
        expect(canned.completions).to eq(1)

        # Redis uses its own clock, so expire the token without waiting for its deadline.
        Discourse.redis.expire(key, 0)
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Corrected outcome" }],
            ),
          )
        }.to raise_error(described_class::ResumeTokenNotFound)
        expect(described_class.resume_state_exists?(token)).to eq(false)
        expect(canned.completions).to eq(1)
      end
    end

    it "rejects both queued and late results for a previous round even when a call ID is reused" do
      first_call, second_call =
        %w[first second].map do |input|
          DiscourseAi::Completions::ToolCall.new(
            id: "read",
            name: "client_tool",
            parameters: {
              input: input,
            },
          )
        end
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [first_call, second_call, "Inventory is ready", "Inventory"],
      ) do |canned|
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        first_results = [{ tool_call_id: first_call.id, content: "First outcome" }]
        winner = build_session(resume_token: token, tool_results: first_results)
        winner_events = nil
        allow(DiscourseAi::AiBot::ReplyLock).to receive(
          :synchronize,
        ).and_wrap_original do |lock, key, &block|
          if winner_events.nil?
            # Let the competing request finish round one before the queued request enters the lock.
            winner_events = []
            winner_events = collect_events(winner)
          end
          lock.call(key, &block)
        end

        expect {
          collect_events(build_session(resume_token: token, tool_results: first_results))
        }.to raise_error(described_class::ResumeTokenNotFound)
        next_token = winner_events.find { |type, _| type == :tool_calls }.last[:resume_token]
        expect(next_token).not_to eq(token)
        expect {
          collect_events(build_session(resume_token: token, tool_results: first_results))
        }.to raise_error(described_class::ResumeTokenNotFound)
        expect(canned.completions).to eq(2)

        second_results = [{ tool_call_id: second_call.id, content: "Second outcome" }]
        collect_events(build_session(resume_token: next_token, tool_results: second_results))
        expect(canned.completions).to eq(4)
        expect(described_class.resume_state_exists?(next_token)).to eq(false)
      end
    end

    it "leaves the pending batch available to its owner after a different admin submits results" do
      other_admin = Fabricate(:admin)
      call = DiscourseAi::Completions::ToolCall.new(id: "read", name: "client_tool", parameters: {})
      DiscourseAi::Completions::Llm.with_prepared_responses([call, "Answer", "Title"]) do |canned|
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        key = described_class.redis_key(token)
        original_state = Discourse.redis.get(key)
        Discourse.redis.expire(key, 2.minutes.to_i)
        ttl_before_rejection = Discourse.redis.pttl(key)

        expect {
          collect_events(
            build_session(
              current_user: other_admin,
              resume_token: token,
              tool_results: [{ tool_call_id: "typo", content: "Unexpected result" }],
            ),
          )
        }.to raise_error(described_class::ResumeTokenNotFound)
        expect(Discourse.redis.get(key)).to eq(original_state)
        expect(Discourse.redis.pttl(key)).to be_between(1, ttl_before_rejection)
        expect(canned.completions).to eq(1)

        results = [{ tool_call_id: call.id, content: "Owner's result" }]
        collect_events(build_session(resume_token: token, tool_results: results))
        expect(canned.completions).to eq(3)
        expect(described_class.resume_state_exists?(token)).to eq(false)
      end
    end

    it "leaves a replaced state untouched if it changes after preflight" do
      call = DiscourseAi::Completions::ToolCall.new(id: "read", name: "client_tool", parameters: {})
      DiscourseAi::Completions::Llm.with_prepared_responses([call, "Answer", "Title"]) do |canned|
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        key = described_class.redis_key(token)
        replacement = Discourse.redis.get(key) + "\n"
        results = [{ tool_call_id: call.id, content: "Checked" }]
        session = build_session(resume_token: token, tool_results: results)
        allow(session).to receive(:preflight_tool_results!).and_wrap_original do |preflight|
          preflight.call.tap do
            # Another writer replaces the saved bytes before this session can claim them.
            Discourse.redis.set(key, replacement, xx: true, keepttl: true)
          end
        end

        expect { collect_events(session) }.to raise_error(described_class::ResumeTokenNotFound)
        expect(Discourse.redis.get(key)).to eq(replacement)
        expect(canned.completions).to eq(1)

        collect_events(build_session(resume_token: token, tool_results: results))
        expect(canned.completions).to eq(3)
      end
    end

    describe "failed multi-round resume" do
      fab!(:permission_group) { Fabricate(:group).tap { |group| group.add(admin) } }

      fab!(:history) do
        post =
          Fabricate(
            :private_message_post,
            user: admin,
            recipient: ai_agent.user,
            raw: "Historical source before editing",
          )
        Fabricate(:post, topic: post.topic, user: ai_agent.user, raw: "Historical bot response")
        Fabricate(:post, topic: post.topic, user: admin, raw: "Another historical source")
        Fabricate(
          :post,
          topic: post.topic,
          user: ai_agent.user,
          raw: "Another historical bot response",
        )
        post
      end

      let(:model_turns) { ["Current round one reasoning", "Current round two reasoning"] }
      let(:caller_results) do
        [
          { tool_call_id: "multi-round-0", content: "Completed first caller result" },
          { tool_call_id: "multi-round-1", content: "Completed second caller result" },
        ]
      end

      def suspend_in_second_caller_round
        calls =
          caller_results.map.with_index do |result, index|
            DiscourseAi::Completions::ToolCall.new(
              name: "client_tool",
              parameters: {
                input: "round #{index}",
              },
              id: result[:tool_call_id],
            )
          end
        DiscourseAi::Completions::Llm.with_prepared_responses(model_turns.zip(calls)) do
          events = collect_events(build_session(topic: history.topic, query: "Current request"))
          token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
          events =
            collect_events(build_session(resume_token: token, tool_results: [caller_results.first]))
          events.find { |type, _| type == :tool_calls }.last[:resume_token]
        end
      end

      it "preserves both caller rounds and current model turns after a failed resume without a checkpoint" do
        token = suspend_in_second_caller_round
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        permission_group.remove(admin)
        original = history.raw
        history.update!(raw: "Corrected historical source")

        DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
          expect {
            collect_events(build_session(resume_token: token, tool_results: [caller_results.last]))
          }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
          expect(canned.completions).to eq(0)
        end

        saved = history.topic.posts.order(:post_number).last.post_custom_prompt.custom_prompt
        expect(saved.select { |entry| entry[2] == "tool" }.map(&:first)).to eq(
          caller_results.pluck(:content),
        )
        expect(saved.select { |entry| entry[2] == "model" }.map(&:first)).to eq(model_turns)
        expect(saved.map { |entry| entry[7] }.uniq).to eq([state["evidence_scope"]])
        expect(saved.to_s).not_to include(original, history.raw, "<compressed_context>")
        expect(Discourse.redis.get(key)).to be_nil
      end

      it "preserves both caller rounds and current model turns but drops a stale checkpoint" do
        token = suspend_in_second_caller_round
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        messages = state["prompt"]["messages"]
        checkpoint_summary = "Old historical summary"
        state["prompt"]["messages"] = [
          messages.first,
          {
            type: "user",
            content: "<compressed_context>#{checkpoint_summary}</compressed_context>",
          },
          {
            type: "model",
            content: DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
          },
          *messages.drop(state["protected_user_index"]),
        ]
        state["protected_user_index"] = 3
        Discourse.redis.set(key, state.to_json)
        permission_group.remove(admin)
        original = history.raw
        history.update!(raw: "Corrected historical source")

        DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
          expect {
            collect_events(build_session(resume_token: token, tool_results: [caller_results.last]))
          }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
          expect(canned.completions).to eq(0)
        end

        saved = history.topic.posts.order(:post_number).last.post_custom_prompt.custom_prompt
        expect(saved.select { |entry| entry[2] == "tool" }.map(&:first)).to eq(
          caller_results.pluck(:content),
        )
        expect(saved.select { |entry| entry[2] == "model" }.map(&:first)).to eq(model_turns)
        expect(saved.map { |entry| entry[7] }.uniq).to eq([state["evidence_scope"]])
        expect(saved.to_s).not_to include(
          original,
          history.raw,
          checkpoint_summary,
          "<compressed_context>",
        )
        expect(Discourse.redis.get(key)).to be_nil
      end
    end

    it "preserves completed caller results when a permission change invalidates the resumed history" do
      group = Fabricate(:group)
      group.add(admin)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "permission-change-read",
        )
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      state = JSON.parse(Discourse.redis.get(described_class.redis_key(token)))
      group.remove(admin)
      result = "Completed caller evidence QUARTZ-OTTER-731"

      DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: result }],
            ),
          )
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
        expect(canned.completions).to eq(0)
      end
      reply = Topic.find(state["topic_id"]).posts.order(:post_number).last
      saved = PostCustomPrompt.find_by!(post_id: reply.id).custom_prompt
      expect(reply.raw).to include("history_changed")
      expect(saved.find { |entry| entry[2] == "tool" }[0]).to eq(result)
      expect(saved.map { |entry| entry[7] }.uniq).to eq([state["evidence_scope"]])
      expect(Discourse.redis.get(described_class.redis_key(token))).to be_nil
    end

    it "preserves the resume deadline for missing and unexpected results after topic access is revoked" do
      call =
        DiscourseAi::Completions::ToolCall.new(
          id: "compound-read",
          name: "client_tool",
          parameters: {
          },
        )
      valid_results = [{ tool_call_id: call.id, content: "Completed result" }]
      unexpected_result = { tool_call_id: "unexpected", content: "Unaccepted result" }

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [call, "Recovered answer", "Title"],
      ) do |canned, _, prompts|
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        key = described_class.redis_key(token)
        original_state = Discourse.redis.get(key)
        topic = Topic.find(JSON.parse(original_state).fetch("topic_id"))
        admin.update!(admin: false, moderator: false)
        topic.topic_allowed_users.where(user_id: admin.id).delete_all
        # Age the state using Redis's clock so an accidental SETEX refresh is observable.
        Discourse.redis.expire(key, 2.minutes.to_i)
        ttl_before_rejection = Discourse.redis.pttl(key)

        invalid_batches = [
          [[], I18n.t("discourse_ai.errors.missing_tool_results", ids: call.id)],
          [
            valid_results + [unexpected_result],
            I18n.t(
              "discourse_ai.errors.unexpected_tool_results",
              ids: unexpected_result[:tool_call_id],
            ),
          ],
        ]
        invalid_batches.each do |batch, message|
          expect {
            collect_events(build_session(resume_token: token, tool_results: batch))
          }.to raise_error(described_class::InvalidToolResults, message)
          expect(Discourse.redis.get(key)).to eq(original_state)
          expect(Discourse.redis.pttl(key)).to be_between(1, ttl_before_rejection)
          expect(canned.completions).to eq(1)
          expect(topic.posts.count).to eq(1)
        end

        admin.update!(admin: true)
        topic.topic_allowed_users.create!(user_id: admin.id)
        collect_events(build_session(resume_token: token, tool_results: valid_results))

        tool_messages = prompts[1].messages.select { |message| message[:type] == :tool }
        expect(tool_messages.pluck(:content)).to eq(valid_results.pluck(:content))
        expect(described_class.resume_state_exists?(token)).to eq(false)
      end
    end

    it "retains caller results privately if topic access is revoked during suspension" do
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "revoked-topic-read",
        )
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      topic = Topic.find(state["topic_id"])
      admin.update!(admin: false, moderator: false)
      topic.topic_allowed_users.where(user_id: admin.id).delete_all
      results = [{ tool_call_id: call.id, content: "Already completed private result" }]

      expect {
        collect_events(build_session(resume_token: token, tool_results: results))
      }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
      expect(topic.posts.count).to eq(1)
      failed_work = JSON.parse(Discourse.redis.get(key))["work_budget"]
      expect(failed_work["used"]).to eq(
        state["work_budget"]["used"] + llm.to_llm.tokenizer.size(results.first[:content]),
      )
      expect {
        collect_events(build_session(resume_token: token, tool_results: results))
      }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
      expect(JSON.parse(Discourse.redis.get(key))["work_budget"]).to eq(failed_work)
      changed_results = [
        { tool_call_id: call.id, content: "Different result must not be admitted" },
      ]
      expect {
        collect_events(build_session(resume_token: token, tool_results: changed_results))
      }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
      expect(JSON.parse(Discourse.redis.get(key))["work_budget"]).to eq(failed_work)
      expect(JSON.parse(Discourse.redis.get(key))["failed_tool_results"]).to eq(
        JSON.parse(results.to_json),
      )
      admin.update!(admin: true)
      topic.topic_allowed_users.create!(user_id: admin.id)
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Recovered answer", "Title"],
      ) do |_, _, prompts|
        collect_events(build_session(resume_token: token, tool_results: changed_results))
        expect(
          prompts
            .first
            .messages
            .select { |message| message[:type] == :tool }
            .map { |message| message[:content] },
        ).to eq([results.first[:content]])
      end
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    it "retains completed caller results privately when the suspended source is deleted" do
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "deleted-source-read",
        )
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      topic = Topic.find(state["topic_id"])
      topic.posts.first.trash!
      results = [{ tool_call_id: call.id, content: "Completed before source deletion" }]

      expect {
        collect_events(build_session(resume_token: token, tool_results: results))
      }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
      expect(JSON.parse(Discourse.redis.get(key))["failed_tool_results"]).to eq(
        JSON.parse(results.to_json),
      )
      expect(topic.posts.count).to eq(0)
    end

    it "keeps the original resume state and reports the bounded storage limit for revoked-access results" do
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "bounded-private-read",
        )
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      topic = Topic.find(state["topic_id"])
      admin.update!(admin: false, moderator: false)
      topic.topic_allowed_users.where(user_id: admin.id).delete_all
      limit = state.to_json.bytesize + 32

      stub_const(described_class, :MAX_REDIS_STATE_BYTES, limit) do
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Completed result " * 100 }],
            ),
          )
        }.to raise_error(
          described_class::ProtocolError,
          I18n.t("discourse_ai.errors.stream_reply_state_too_large", max: limit),
        )
      end
      expect(JSON.parse(Discourse.redis.get(key))).to eq(state)
      expect(topic.posts.count).to eq(1)
    end

    it "restores sources interleaved before a delayed custom-tools checkpoint carrier" do
      llm.update!(max_prompt_tokens: 16_000)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "delayed-carrier-read",
        )
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session(query: "Remember QUARTZ-OTTER-731"))
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      state = JSON.parse(Discourse.redis.get(described_class.redis_key(token)))
      topic = Topic.find(state["topic_id"])
      gap =
        Fabricate(
          :post,
          topic: topic,
          user: admin,
          raw: "Interleaved during custom tool suspension",
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Checkpoint remembers QUARTZ-OTTER-731"),
      ) do
        collect_events(
          build_session(
            resume_token: token,
            tool_results: [
              { tool_call_id: call.id, content: "Oversized completed result " * 4000 },
            ],
          ),
        )
      end
      carrier = topic.posts.order(:post_number).last
      entries = PostCustomPrompt.find_by!(post_id: carrier.id).custom_prompt
      expect(entries.first[0]).to start_with("<compressed_context>")
      expect(entries.first[6]["source_id"]).to eq(topic.posts.first.id)
      latest =
        Fabricate(
          :post,
          topic: topic,
          user: admin,
          raw: "Follow up without losing the interleaved evidence",
        )
      snapshot =
        DiscourseAi::Completions::HistorySnapshot.post(
          latest,
          guardian: admin.guardian,
          bot_usernames: [ai_agent.user.username],
        )
      messages =
        DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
          latest,
          max_posts: 2,
          bot_usernames: [ai_agent.user.username],
          history_snapshot: snapshot,
        )
      expect(messages.to_s).to include("QUARTZ-OTTER-731", gap.raw, carrier.raw, latest.raw)
      expect(messages.to_s.index(gap.raw)).to be < messages.to_s.rindex(carrier.raw)

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Restored continuation"],
      ) do |canned, _, prompts|
        collect_events(build_session(topic: topic, query: "Continue again"))
        expect(canned.completions).to eq(1)
        expect(prompts.first.messages.to_s).to include(gap.raw)
      end
      newest_carrier = topic.posts.order(:post_number).last
      inherited = PostCustomPrompt.find_by!(post_id: newest_carrier.id).custom_prompt
      newest = Fabricate(:post, topic: topic, user: admin, raw: "Restore the inherited checkpoint")
      snapshot =
        DiscourseAi::Completions::HistorySnapshot.post(
          newest,
          guardian: admin.guardian,
          bot_usernames: [ai_agent.user.username],
        )
      restored =
        DiscourseAi::Completions::PromptMessagesBuilder.messages_from_post(
          newest,
          max_posts: 2,
          bot_usernames: [ai_agent.user.username],
          history_snapshot: snapshot,
        )
      expect(restored.to_s).to include(gap.raw, newest_carrier.raw, newest.raw)
      expect(inherited.first[6]["source_id"]).to eq(topic.posts.find_by!(raw: "Continue again").id)
    end

    it "keeps the current request and reply evidence boundaries when normalizing saved history" do
      topic = Fabricate(:private_message_post, user: admin, recipient: ai_agent.user).topic
      query = "Continue with the current inventory check."
      first_call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "inventory")
      second_call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "confirm")
      first_result = "Inventory checked"
      second_result = "Inventory confirmed"
      answer = "The inventory is ready."

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [first_call, second_call, answer],
      ) do |canned|
        events = collect_events(build_session(topic: topic, query: query))
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        history = [
          { type: "model", content: "Old inventory reply" },
          { type: "system", content: "Private old system instructions" },
          { type: "model", content: "Old inventory follow-up" },
        ]
        state["prompt"]["messages"].insert(1, *history)
        state["initial_prompt_message_count"] += history.size
        state["protected_user_index"] += history.size
        Discourse.redis.set(key, state.to_json)

        events =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: first_call.id, content: first_result }],
            ),
          )
        tool_event = events.find { |type, _| type == :tool_calls }.last
        expect(tool_event[:tool_calls].pluck(:id)).to eq([second_call.id])
        token = tool_event[:resume_token]
        resumed_state = JSON.parse(Discourse.redis.get(described_class.redis_key(token)))
        request = resumed_state["prompt"]["messages"].fetch(resumed_state["protected_user_index"])
        expect(request).to include("type" => "user", "content" => a_string_including(query))

        collect_events(
          build_session(
            resume_token: token,
            tool_results: [{ tool_call_id: second_call.id, content: second_result }],
          ),
        )

        reply = topic.posts.order(:post_number).last
        expect(reply).to have_attributes(user: ai_agent.user, raw: answer)
        evidence = reply.post_custom_prompt.custom_prompt
        expect(evidence.map { |entry| entry.values_at(2, 1, 0) }).to match(
          [
            ["tool_call", first_call.id, a_kind_of(String)],
            ["tool", first_call.id, first_result],
            ["tool_call", second_call.id, a_kind_of(String)],
            ["tool", second_call.id, second_result],
            ["model", nil, answer],
          ],
        )
        expect(canned.completions).to eq(3)
        expect(described_class.resume_state_exists?(token)).to eq(false)
      end
    end

    it "protects the real request instead of a trailing budget hint when restoring an unindexed session" do
      # A user can quote a marker verbatim; only the unattributed copy is the bot's hint.
      query = DiscourseAi::Agents::Bot::LEGACY_BUDGET_EXHAUSTED_HINT
      first =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", id: "read", parameters: {})
      second =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", id: "confirm", parameters: {})

      DiscourseAi::Completions::Llm.with_prepared_responses([first, second]) do
        events = collect_events(build_session(query: query))
        token = events.find { |type, _| type == :tool_calls }.last.fetch(:resume_token)
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        request =
          state.fetch("prompt").fetch("messages").fetch(state.delete("protected_user_index"))
        expect(request).to include("content" => query, "id" => admin.username)
        state.fetch("prompt").fetch("messages") << { type: "user", content: query }
        Discourse.redis.setex(key, described_class::RESUME_STATE_TTL_SECONDS, state.to_json)

        events =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: first.id, content: "Read once" }],
            ),
          )
        next_token = events.find { |type, _| type == :tool_calls }.last.fetch(:resume_token)
        resumed = JSON.parse(Discourse.redis.get(described_class.redis_key(next_token)))
        expect(
          resumed.fetch("prompt").fetch("messages").fetch(resumed.fetch("protected_user_index")),
        ).to eq(request)
      end
    end

    it "protects the source request and additional current instructions while preparing a resumed result" do
      llm.update!(max_prompt_tokens: 16_000)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "protected-read",
        )
      token = nil
      query = "Keep this exact current request QUARTZ-OTTER-731"
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session(query: query))
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      extra = "Additional current instructions: preserve the exact answer"
      state["prompt"]["messages"] << { type: "user", content: extra }
      Discourse.redis.set(key, state.to_json)
      result = "Completed tool evidence " * 6000
      DiscourseAi::Completions::Llm.with_prepared_responses(
        Array.new(8, "Summary of completed evidence"),
      ) do |_, _, prompts, options|
        collect_events(
          build_session(
            resume_token: token,
            tool_results: [{ tool_call_id: call.id, content: result }],
          ),
        )
        maintenance =
          prompts
            .zip(options)
            .select { |_, option| option[:feature_name] == "context_compression" }
            .map(&:first)
        expect(maintenance).to be_present
        expect(maintenance.map(&:messages).to_s).not_to include(query, extra)
        answering_prompt =
          prompts.zip(options).find { |_, option| option[:feature_name] == "bot" }.first
        expect(answering_prompt.messages.to_s).to include(query, extra)
      end
    end

    it "persists partial text and completed caller-owned tool evidence after hard maintenance failure" do
      llm.update!(max_prompt_tokens: 16_000)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "side effect",
          },
          id: "completed-action",
        )
      token = nil
      topic_id = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [["Partial answer before the action", call]],
      ) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
        topic_id = events.find { |type, _| type == :context }[1][:topic_id]
      end
      result = "Executed action with important evidence " * 4500
      DiscourseAi::Completions::Llm.with_prepared_responses([""]) do
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: result }],
            ),
          )
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /empty_summary/)
      end
      reply = Post.where(topic_id: topic_id, user: ai_agent.user).last
      expect(reply.raw).to include("Partial answer before the action", "empty_summary")
      expect(reply.post_custom_prompt.custom_prompt.to_s).to include(result, call.id)
      expect(reply.post_custom_prompt.custom_prompt.to_s).not_to include("<compressed_context>")
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    it "ignores retired preparation budget fields when resuming a legacy payload" do
      llm.update!(max_prompt_tokens: 16_000)
      ai_agent.update!(max_turn_tokens: 200_000)
      call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "legacy")
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session).find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state.delete("completion_count")
      state.merge!(
        "preparation_calls" => 8,
        "preparation_elapsed_seconds" => 1000,
        "preparation_spent_tokens" => 10_000_000,
        "preparation_tokens" => 123,
      )
      Discourse.redis.set(key, state.to_json)
      next_token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["First summary", "Complete summary", call],
      ) do |_, _, _, options|
        events =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Oversized result " * 6000 }],
            ),
          )
        next_token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
        expect(options.map { |option| option[:feature_name] }).to eq(
          %w[context_compression context_compression bot],
        )
      end
      resumed_state = JSON.parse(Discourse.redis.get(described_class.redis_key(next_token)))
      expect(resumed_state["completion_count"]).to eq(4)
      expect(resumed_state["preparation_tokens"]).to eq(123)
      expect(
        resumed_state.keys &
          %w[preparation_calls preparation_elapsed_seconds preparation_spent_tokens],
      ).to eq([])
    end

    it "persists compaction completions across resumes and preserves the root final completion" do
      llm.update!(max_prompt_tokens: 16_000)
      ai_agent.update!(max_turn_tokens: 200_000)
      call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "limited")
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session).find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state["completion_count"] = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 4
      Discourse.redis.set(key, state.to_json)
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["First summary", "Complete summary", call],
      ) do
        events =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Oversized result " * 6000 }],
            ),
          )
        token = events.find { |type, _| type == :tool_calls }.last[:resume_token]
      end
      expect(
        JSON.parse(Discourse.redis.get(described_class.redis_key(token)))["completion_count"],
      ).to eq(DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 1)

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Final answer at the execution limit", "Test title"],
      ) do |_, _, prompts|
        events =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Done" }],
            ),
          )
        expect(events.select { |type, _| type == :partial }.map(&:last).join).to eq(
          "Final answer at the execution limit",
        )
        expect(prompts.first.tool_choice).to eq(:none)
        expect(prompts.first.messages[-2][:content]).to eq(
          DiscourseAi::Agents::Bot::COMPLETION_LIMIT_FINAL_ANSWER_HINT,
        )
        expect(described_class.resume_state_exists?(token)).to eq(false)
      end
    end

    it "uses the last ordinary slot for current-turn maintenance and the reserved slot for a text-only final" do
      llm.update!(max_prompt_tokens: 16_000)
      ai_agent.update!(max_turn_tokens: 200_000)
      call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "boundary")
      query = "request " * 11_000
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session(query: query)).find { |type, _| type == :tool_calls }[1][
            :resume_token
          ]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      expect(state["prompt"]["messages"].map { |message| message["type"] }).to eq(%w[system user])
      state["completion_count"] = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 2
      Discourse.redis.set(key, state.to_json)
      summary = "The completed caller action returned useful evidence."
      final = "Final answer using the completed action"
      result = "Completed evidence " * 2000
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [summary, final, "Test title"],
      ) do |_, _, prompts, options|
        events =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: result }],
            ),
          )
        expect(options.map { |option| option[:feature_name] }.first(2)).to eq(
          %w[context_compression bot],
        )
        expect(prompts.first.messages.last[:content]).to include(result)
        expect(prompts[1].messages[1][:content]).to eq(
          "<compressed_context>#{summary}</compressed_context>",
        )
        expect(prompts[1].tool_choice).to eq(:none)
        expect(prompts[1].messages.map { |message| message[:content] }).to include(
          DiscourseAi::Agents::Bot::COMPLETION_LIMIT_FINAL_ANSWER_HINT,
        )
        expect(options[1]).to include(max_tokens: 4096, thinking_effort: "none")
        size, capacity = llm.to_llm.prompt_capacity(prompts[1], **options[1])
        expect(size).to be_between(capacity * 0.8, capacity)
        expect(events.select { |type, _| type == :partial }.map(&:last).join).to eq(final)
        expect(events.select { |type, _| type == :tool_calls }).to eq([])
      end
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    it "rejects a final whose changed output allowance no longer leaves room for the current request" do
      llm.update!(max_prompt_tokens: 16_000)
      ai_agent.update!(max_turn_tokens: 200_000)
      call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "capacity")
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session(query: "request " * 12_000)).find do |type, _|
            type == :tool_calls
          end[
            1
          ][
            :resume_token
          ]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state["completion_count"] = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 2
      Discourse.redis.set(key, state.to_json)
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Completed caller evidence summarized."],
      ) do |canned, _, _, options|
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Completed evidence " * 2000 }],
            ),
          )
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /hard_overflow/)
        expect(canned.completions).to eq(1)
        expect(options.map { |option| option[:feature_name] }).to eq(["context_compression"])
      end
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    context "when topic access is revoked during maintenance" do
      let(:tool_result) { { tool_call_id: "failed-final", content: "Completed evidence " * 2000 } }
      let(:credit_error) { LlmCreditAllocation::CreditLimitExceeded.new("credits exhausted") }

      def suspend_before_last_ordinary_completion
        llm.update!(max_prompt_tokens: 16_000)
        ai_agent.update!(max_turn_tokens: 200_000)
        call =
          DiscourseAi::Completions::ToolCall.new(
            name: "client_tool",
            parameters: {
            },
            id: tool_result[:tool_call_id],
          )
        token =
          DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
            events = collect_events(build_session(query: "request " * 11_000))
            events.find { |type, _| type == :tool_calls }.last[:resume_token]
          end
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        state["completion_count"] = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 2
        Discourse.redis.set(key, state.to_json)
        token
      end

      def revoke_access_during_compression(topic)
        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |generate, *args, **options, &block|
          if options[:feature_name] == "context_compression"
            options[:user].update!(admin: false, moderator: false)
            topic.topic_allowed_users.where(user_id: admin.id).delete_all
          end
          generate.call(*args, **options, &block)
        end
      end

      it "persists the spent maintenance completion and leaves the reserved final unspent" do
        token = suspend_before_last_ordinary_completion
        key = described_class.redis_key(token)
        topic = Topic.find(JSON.parse(Discourse.redis.get(key)).fetch("topic_id"))
        revoke_access_during_compression(topic)

        DiscourseAi::Completions::Llm.with_prepared_responses([credit_error]) do
          expect {
            collect_events(build_session(resume_token: token, tool_results: [tool_result]))
          }.to raise_error(LlmCreditAllocation::CreditLimitExceeded)
        end

        completion_count = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 1
        expect(JSON.parse(Discourse.redis.get(key))).to include(
          "completion_count" => completion_count,
          "failed_tool_results" => [tool_result.stringify_keys],
        )
        expect {
          collect_events(build_session(resume_token: token, tool_results: [tool_result]))
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
        expect(JSON.parse(Discourse.redis.get(key))["completion_count"]).to eq(completion_count)
      end

      it "persists both spent completions when maintenance succeeds but the reserved final fails" do
        token = suspend_before_last_ordinary_completion
        key = described_class.redis_key(token)
        topic = Topic.find(JSON.parse(Discourse.redis.get(key)).fetch("topic_id"))
        revoke_access_during_compression(topic)

        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["Completed caller evidence summarized.", credit_error],
        ) do
          expect {
            collect_events(build_session(resume_token: token, tool_results: [tool_result]))
          }.to raise_error(LlmCreditAllocation::CreditLimitExceeded)
        end

        completion_count = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS
        expect(JSON.parse(Discourse.redis.get(key))).to include(
          "completion_count" => completion_count,
          "failed_tool_results" => [tool_result.stringify_keys],
        )
        expect {
          collect_events(build_session(resume_token: token, tool_results: [tool_result]))
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
        expect(JSON.parse(Discourse.redis.get(key))["completion_count"]).to eq(completion_count)
      end
    end

    it "preserves completed results when the execution completion limit blocks required compaction" do
      llm.update!(max_prompt_tokens: 16_000)
      call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "completed")
      token = nil
      topic_id = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
        topic_id = events.find { |type, _| type == :context }[1][:topic_id]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state["completion_count"] = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS - 1
      Discourse.redis.set(key, state.to_json)
      result = "Completed evidence " * 6000
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: result }],
            ),
          )
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /completion_limit/)
        expect(canned.completions).to eq(0)
      end
      reply = Post.where(topic_id: topic_id, user: ai_agent.user).last
      expect(reply.post_custom_prompt.custom_prompt.to_s).to include(result, call.id)
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    it "rejects a resumed generation when the reserved final completion has already been consumed" do
      call =
        DiscourseAi::Completions::ToolCall.new(name: "client_tool", parameters: {}, id: "exhausted")
      token = nil
      topic_id = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        events = collect_events(build_session)
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
        topic_id = events.find { |type, _| type == :context }[1][:topic_id]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state["completion_count"] = DiscourseAi::Agents::SubagentExecutionState::MAX_COMPLETIONS
      Discourse.redis.set(key, state.to_json)
      result = "Already completed"
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |canned|
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: result }],
            ),
          )
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /completion_limit/)
        expect(canned.completions).to eq(0)
      end
      reply = Post.where(topic_id: topic_id, user: ai_agent.user).last
      expect(reply.post_custom_prompt.custom_prompt.to_s).to include(result, call.id)
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    it "prepares initial tool-heavy history and persists the prepared prompt while calls are pending" do
      llm.update!(max_prompt_tokens: 16_000)
      ai_agent.update!(compression_threshold: 50)
      source = Fabricate(:private_message_post, user: admin, recipient: ai_agent.user)
      source.update!(raw: "Remember QUARTZ-OTTER-731")
      old_reply =
        Fabricate(:post, topic: source.topic, user: ai_agent.user, raw: "The data was read.")
      old_result = "Record: amber item checked. " * 1800
      PostCustomPrompt.create!(
        post_id: old_reply.id,
        custom_prompt: [
          %w[{"arguments":{}} old tool_call client_tool],
          [old_result, "old", "tool", "client_tool"],
          ["DATA READ", ai_agent.user.username],
        ],
      )
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "next",
          },
          id: "next",
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Remember QUARTZ-OTTER-731; previous read succeeded.", tool_call],
      ) do |_, _, prompts, options|
        events = collect_events(build_session(topic: source.topic, query: "What codeword?"))
        token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
        state = JSON.parse(Discourse.redis.get(described_class.redis_key(token)))

        expect(options.map { |option| option[:feature_name] }).to eq(%w[context_compression bot])
        expect(prompts.first.messages.last[:content]).to include(source.raw, old_result)
        expect(state["prompt"]["messages"][1]["content"]).to include("<compressed_context>")
        expect(state["expected_tool_calls"].map { |call| call["id"] }).to eq(["next"])
        expect(state["completion_count"]).to eq(2)
      end
    end

    it "compacts an oversized completed resumed result before answering and saves a reusable checkpoint" do
      llm.update!(max_prompt_tokens: 16_000)
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "read",
        )
      large_result = "Record: amber item checked. " * 4000
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [
          tool_call,
          "First fragment summary.",
          "Read evidence retained.",
          "Answer after maintenance.",
          "Test title",
        ],
      ) do |_, _, prompts, options|
        event =
          collect_events(
            build_session(query: "Remember QUARTZ-OTTER-731 and read"),
          ).find { |type, _| type == :tool_calls }
        events =
          collect_events(
            build_session(
              resume_token: event[1][:resume_token],
              tool_results: [{ tool_call_id: "read", content: large_result }],
            ),
          )
        expect(events.select { |type, _| type == :partial }.map(&:last).join).to eq(
          "Answer after maintenance.",
        )
        expect(options.map { |option| option[:feature_name] }.first(4)).to eq(
          %w[bot context_compression context_compression bot],
        )
        protected_request = prompts[3].messages.select { |message| message[:type] == :user }.last
        expect(Array(protected_request[:content])).to include(
          "Remember QUARTZ-OTTER-731 and read",
          DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT,
        )
        reply = Post.where(user_id: ai_agent.user_id).order(:id).last
        checkpoint = reply.post_custom_prompt.custom_prompt.first
        expect(checkpoint[0]).to include("<compressed_context>")
        expect(checkpoint[6]).to include(
          "version" => DiscourseAi::Completions::HistorySnapshot::VERSION,
          "user_id" => admin.id,
        )
      end
    end

    it "retains pending tool thinking signatures through resume" do
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "read",
        )
      thinking =
        DiscourseAi::Completions::Thinking.new(
          message: "Inspect the source",
          provider_info: {
            anthropic: {
              signature: "signed-thinking",
            },
          },
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [[thinking, tool_call], "Final answer", "Title"],
      ) do |_, _, prompts|
        event = collect_events(build_session).find { |type, _| type == :tool_calls }
        state = JSON.parse(Discourse.redis.get(described_class.redis_key(event[1][:resume_token])))
        expect(state["expected_tool_calls"].first).to include(
          "thinking" => thinking.message,
          "thinking_provider_info" => {
            "anthropic" => {
              "signature" => "signed-thinking",
            },
          },
        )
        collect_events(
          build_session(
            resume_token: event[1][:resume_token],
            tool_results: [{ tool_call_id: "read", content: "Read result" }],
          ),
        )
        restored = prompts.second.messages.find { |message| message[:type] == :tool_call }
        expect(restored).to include(
          thinking: thinking.message,
          thinking_provider_info: thinking.provider_info,
        )
      end
    end

    it "reconstructs resumed parallel vLLM tool calls as one assistant batch" do
      vllm_model = Fabricate(:vllm_model)
      ai_agent.update!(default_llm_id: vllm_model.id)
      provider_data = { vllm: { tool_batch_id: "response-1" } }
      tool_calls =
        %w[one two].map do |input|
          DiscourseAi::Completions::ToolCall.new(
            name: "client_tool",
            parameters: {
              input: input,
            },
            id: "tool_#{input}",
            provider_data: provider_data,
          )
        end

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_calls, "Final answer after tools.", "Test title"],
      ) do |_, _, prompts|
        tool_event = collect_events(build_session).find { |type, _| type == :tool_calls }

        collect_events(
          build_session(
            resume_token: tool_event[1][:resume_token],
            tool_results: [
              { tool_call_id: "tool_one", content: "first result" },
              { tool_call_id: "tool_two", content: "second result" },
            ],
          ),
        )

        translated =
          DiscourseAi::Completions::Dialects::Vllm.new(prompts.second, vllm_model).translate
        assistant_tool_messages = translated.select { |message| message[:tool_calls] }

        expect(
          assistant_tool_messages.map { |message| message[:tool_calls].map { |call| call[:id] } },
        ).to eq([%w[tool_one tool_two]])
      end
    end
  end

  describe "token budget enforcement" do
    it "hands out and resumes the largest caller batch the HTTP API accepts" do
      calls =
        20.times.map do |index|
          DiscourseAi::Completions::ToolCall.new(
            id: "batch-#{index}",
            name: "client_tool",
            parameters: {
              input: "read",
            },
          )
        end

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [calls, "Batch summary", "Title"],
      ) do |canned|
        events = collect_events(build_session)
        payload = events.find { |type, _| type == :tool_calls }.last
        token = payload.fetch(:resume_token)
        expect(payload.fetch(:tool_calls).pluck(:id)).to eq(calls.map(&:id))

        results = calls.map { |call| { tool_call_id: call.id, content: "Done" } }
        collect_events(build_session(resume_token: token, tool_results: results))
        expect(canned.completions).to eq(3)
        expect(described_class.resume_state_exists?(token)).to eq(false)
      end
    end

    it "does not offer more caller tools than can be submitted in one HTTP resume" do
      calls =
        21.times.map do |index|
          DiscourseAi::Completions::ToolCall.new(
            id: "surplus-#{index}",
            name: "client_tool",
            parameters: {
            },
          )
        end
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [calls, "Batch summary", "Title"],
      ) do |_, _, prompts, options|
        session = build_session
        events = collect_events(session)
        expect(events.map(&:first)).not_to include(:tool_calls)
        final = prompts[1]
        wrappers = final.messages.select { |message| message[:type] == :tool }
        expect(wrappers.size).to eq(calls.size)
        expect(wrappers.map { |message| JSON.parse(message[:content])["error"] }.uniq).to eq(
          ["Not executed — work allowance or tool batch limit reached."],
        )
        expect(final.tool_choice).to eq(:none)
        expect(options[1][:max_tokens]).to eq(4096)
        generation = DiscourseAi::Completions::GeneratedOutput.new
        calls.each { |call| generation << call }
        generation << "Batch summary"
        expected =
          generation.size(llm.to_llm.tokenizer) +
            wrappers.sum { |message| llm.to_llm.tokenizer.size(message[:content]) }
        expect(session.instance_variable_get(:@work_budget).used).to eq(expected)
      end
    end

    it "prepares an exhausted tight-window caller final using its bounded output" do
      llm.update!(max_prompt_tokens: 16_000, max_output_tokens: 12_000)
      ai_agent.update!(max_turn_tokens: 4000)
      call =
        DiscourseAi::Completions::ToolCall.new(id: "tight", name: "client_tool", parameters: {})
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [call, "Final", "Title"],
      ) do |_, _, _, options|
        token =
          collect_events(build_session(query: "input " * 8000)).find do |type, _|
            type == :tool_calls
          end[
            1
          ][
            :resume_token
          ]
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        state["work_budget"]["used"] = 4000
        Discourse.redis.setex(key, described_class::RESUME_STATE_TTL_SECONDS, state.to_json)
        collect_events(
          build_session(
            resume_token: token,
            tool_results: [{ tool_call_id: call.id, content: "Result" }],
          ),
        )
        expect(
          options
            .select { |option| option[:feature_name] == "bot" }
            .map { |option| option[:max_tokens] },
        ).to eq([2000, 4096])
        expect(options.map { |option| option[:feature_name] }).not_to include("context_compression")
      end
    end

    it "preserves an unclaimed final when caller provider output cannot be bounded" do
      call =
        DiscourseAi::Completions::ToolCall.new(id: "final", name: "client_tool", parameters: {})
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session).find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state["work_budget"]["used"] = 5000
      Discourse.redis.setex(key, described_class::RESUME_STATE_TTL_SECONDS, state.to_json)
      allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(:prompt_capacity).and_return(
        [100, 20_000, 8192],
      )
      session =
        build_session(
          resume_token: token,
          tool_results: [{ tool_call_id: call.id, content: "Result" }],
        )
      DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
        expect { collect_events(session) }.to raise_error(
          DiscourseAi::Completions::ContextPreparation::Error,
          /final_output_limit/,
        )
        expect(canned.completions).to eq(0)
      end
      # The failed turn is terminal, but the ledger must not claim a dispatch that never occurred.
      expect(session.instance_variable_get(:@work_budget).snapshot[:final_answer_claimed]).to eq(
        false,
      )
    end

    it "caps text-only caller sessions at the requested work rather than model output capacity" do
      llm.update!(max_prompt_tokens: 200_000, max_output_tokens: 50_000)
      ai_agent.update!(max_turn_tokens: 4000, compression_threshold: 50)
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Bounded reply", "Title"],
      ) do |_, _, _, options|
        collect_events(build_session(custom_tools: [], query: "Current input " * 3000))
        expect(options.first[:max_tokens]).to eq(4000)
      end
    end

    it "preserves monotonic work and distinct result events across multiple caller rounds" do
      calls =
        2.times.map do
          DiscourseAi::Completions::ToolCall.new(
            id: "reused-id",
            name: "client_tool",
            parameters: {
              input: "read",
            },
          )
        end
      result = "Same external evidence"
      DiscourseAi::Completions::Llm.with_prepared_responses([*calls, "Final reply", "Title"]) do
        event = collect_events(build_session).find { |type, _| type == :tool_calls }
        token = event[1][:resume_token]
        first = JSON.parse(Discourse.redis.get(described_class.redis_key(token)))
        ai_agent.update!(max_turn_tokens: 9000)
        event =
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: "reused-id", content: result }],
            ),
          ).find { |type, _| type == :tool_calls }
        next_token = event[1][:resume_token]
        expect(next_token).not_to eq(token)
        expect(described_class.resume_state_exists?(token)).to eq(false)
        second = JSON.parse(Discourse.redis.get(described_class.redis_key(next_token)))
        output = DiscourseAi::Completions::GeneratedOutput.new
        output << calls.second
        expect(second["work_budget"]["limit"]).to eq(5000)
        expect(second["work_budget"]["used"]).to eq(
          first["work_budget"]["used"] + output.size(llm.to_llm.tokenizer) +
            llm.to_llm.tokenizer.size(result),
        )
        expect(second["work_budget"]["event_ids"]).to include("client_tool:1:reused-id")
        collect_events(
          build_session(
            resume_token: next_token,
            tool_results: [{ tool_call_id: "reused-id", content: result }],
          ),
        )
        expect(described_class.resume_state_exists?(next_token)).to eq(false)
      end
    end

    it "rejects pre-work accounting resume versions rather than minting a fresh work allowance" do
      call =
        DiscourseAi::Completions::ToolCall.new(id: "old-state", name: "client_tool", parameters: {})
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session).find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      state["version"] = 2
      state.delete("work_budget")
      Discourse.redis.setex(key, described_class::RESUME_STATE_TTL_SECONDS, state.to_json)
      DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Result" }],
            ),
          )
        }.to raise_error(
          DiscourseAi::Completions::ContextPreparation::Error,
          /unsupported_resume_state/,
        )
        expect(canned.completions).to eq(0)
      end
    end

    it "admits large current input while persisting the exact requested work allowance" do
      llm.update!(max_prompt_tokens: 50_000)
      ai_agent.update!(max_turn_tokens: 8000, compression_threshold: 50)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "read",
        )
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do |_, _, prompts|
        event =
          collect_events(build_session(query: "input " * 30_000)).find do |type, _|
            type == :tool_calls
          end
        expect(event).to be_present
        state = JSON.parse(Discourse.redis.get(described_class.redis_key(event[1][:resume_token])))
        input, _, output = DiscourseAi::Completions::Llm.proxy(llm).prompt_capacity(prompts.first)
        expect(input + output).to be > 8000
        expect(state["work_budget"]["limit"]).to eq(8000)
        expect(state["work_budget"]["used"]).to be < 100
        expect(prompts.first.tool_choice).not_to eq(:none)
        expect(ai_agent.reload.max_turn_tokens).to eq(8000)
      end
    end

    it "persists work across resumes independently of large repeated request usage" do
      llm.update!(max_prompt_tokens: 50_000)
      ai_agent.update!(max_turn_tokens: 8000, compression_threshold: 80)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "read",
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [call, "Final answer", "Title"],
      ) do |_, _, prompts|
        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |generate, *args, **options, &block|
          result = generate.call(*args, **options, &block)
          tracker = options[:execution_context]&.token_usage_tracker
          tracker&.add_effective(request: 40_000, response: 0)
          result
        end
        event = collect_events(build_session).find { |type, _| type == :tool_calls }
        state = JSON.parse(Discourse.redis.get(described_class.redis_key(event[1][:resume_token])))
        expect(state["work_budget"]["limit"]).to eq(8000)
        expect(prompts.first.tool_choice).not_to eq(:none)
        collect_events(
          build_session(
            resume_token: event[1][:resume_token],
            tool_results: [{ tool_call_id: "read", content: "Read result" }],
          ),
        )
        expect(prompts.second.tool_choice).not_to eq(:none)
        expect(ai_agent.reload.max_turn_tokens).to eq(8000)
      end
    end

    it "enforces budget before generate when resuming over budget" do
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "hello",
          },
          id: "tool_1",
        )

      generated_requests = []
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Final answer after budget pre-check.", "Test title"],
      ) do
        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          prompt = args.first
          generated_requests << {
            tool_choice: prompt.tool_choice,
            last_message: prompt.messages.last.dup,
          }
          original.call(*args, **kwargs, &blk)
        end

        session = build_session
        events = collect_events(session)

        tool_event = events.find { |type, _| type == :tool_calls }
        expect(tool_event).to be_present

        resume_token = tool_event[1][:resume_token]

        # Restore an exhausted work allowance, independently of spending counters.
        raw = Discourse.redis.get(described_class.redis_key(resume_token))
        state = JSON.parse(raw)
        state["work_budget"]["used"] = 5000
        state["accumulated_tokens"] = 999_999
        state["accumulated_request_tokens"] = 999_999
        state["accumulated_response_tokens"] = 0
        Discourse.redis.setex(
          described_class.redis_key(resume_token),
          described_class::RESUME_STATE_TTL_SECONDS,
          state.to_json,
        )

        # Resume with tool results — budget already exceeded before generate
        resumed_events = []
        resumed_session =
          build_session(
            resume_token: resume_token,
            tool_results: [{ tool_call_id: "tool_1", content: "tool output" }],
          )
        resumed_session.run { |type, data| resumed_events << [type, data] }

        partials = resumed_events.select { |type, _| type == :partial }.map { |_, data| data }
        expect(partials.join).to eq("Final answer after budget pre-check.")
        finalization_request =
          generated_requests.find do |request|
            request[:last_message][:content] ==
              DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT
          end
        expect(finalization_request).to eq(
          tool_choice: :none,
          last_message: {
            type: :user,
            content: DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT,
          },
        )

        tool_events = resumed_events.select { |type, _| type == :tool_calls }
        expect(tool_events).to be_empty
      end
    end

    it "triggers synthetic tool errors + final text when budget exhausted mid-round" do
      ai_agent.update!(max_turn_tokens: 1)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "test",
          },
          id: "tool_2",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Summary after budget hit."],
      ) do
        session = build_session

        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          result = original.call(*args, **kwargs, &blk)
          if (tracker = kwargs[:execution_context]&.token_usage_tracker)
            tracker.add_effective(request: 120_000, response: 500)
          end
          result
        end

        events = collect_events(session)

        partials = events.select { |type, _| type == :partial }.map { |_, data| data }
        expect(partials.join).to eq("Summary after budget hit.")

        tool_events = events.select { |type, _| type == :tool_calls }
        expect(tool_events).to be_empty
      end
    end

    it "defaults work to DEFAULT_MAX_TURN_TOKENS" do
      ai_agent.update!(max_turn_tokens: nil)

      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "test",
          },
          id: "tool_4",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Summary after budget hit."],
      ) do
        session = build_session

        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          result = original.call(*args, **kwargs, &blk)
          # Normalized output consumes the default work allowance.
          if (tracker = kwargs[:execution_context]&.token_usage_tracker)
            tracker.add_effective(request: 90_000, response: 30_000)
            kwargs[:execution_context].work_budget.debit(
              DiscourseAi::Agents::Bot::DEFAULT_MAX_TURN_TOKENS,
              event_id: SecureRandom.uuid,
            )
          end
          result
        end

        events = collect_events(session)

        partials = events.select { |type, _| type == :partial }.map { |_, data| data }
        expect(partials.join).to eq("Summary after budget hit.")

        tool_events = events.select { |type, _| type == :tool_calls }
        expect(tool_events).to be_empty
      end
    end

    it "persists request and response token counters in resume state" do
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "hello",
          },
          id: "tool_3",
        )

      DiscourseAi::Completions::Llm.with_prepared_responses([tool_call]) do
        session = build_session

        allow_any_instance_of(DiscourseAi::Completions::Llm).to receive(
          :generate,
        ).and_wrap_original do |original, *args, **kwargs, &blk|
          result = original.call(*args, **kwargs, &blk)
          if (tracker = kwargs[:execution_context]&.token_usage_tracker)
            tracker.add_effective(request: 123, response: 45)
          end
          result
        end

        events = collect_events(session)
        tool_event = events.find { |type, _| type == :tool_calls }
        expect(tool_event).to be_present

        state =
          JSON.parse(Discourse.redis.get(described_class.redis_key(tool_event[1][:resume_token])))
        expect(state["accumulated_request_tokens"]).to eq(123)
        expect(state["accumulated_response_tokens"]).to eq(45)
        expect(state["accumulated_tokens"]).to eq(168)
      end
    end

    it "propagates llm errors" do
      DiscourseAi::Completions::Llm.with_prepared_responses([RuntimeError.new("boom")]) do
        session = build_session
        expect { collect_events(session) }.to raise_error(RuntimeError, "boom")
      end
    end
  end
end
