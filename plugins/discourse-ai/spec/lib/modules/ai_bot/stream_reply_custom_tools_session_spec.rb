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

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
  end

  def build_session(
    query: "test question",
    resume_token: nil,
    tool_results: nil,
    topic: nil,
    custom_tools: self.custom_tools
  )
    described_class.new(
      agent: ai_agent,
      llm_model: resume_token ? nil : ai_agent.default_llm,
      user: admin,
      topic: topic,
      query: query,
      custom_instructions: nil,
      current_user: admin,
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

      [false, true].each do |with_checkpoint|
        it "preserves both caller rounds and current model turns after failed resume #{with_checkpoint ? "with" : "without"} a checkpoint" do
          topic = history.topic
          calls =
            2.times.map do |index|
              DiscourseAi::Completions::ToolCall.new(
                name: "client_tool",
                parameters: {
                  input: "round #{index}",
                },
                id: "multi-round-#{index}",
              )
            end
          model_turns = ["Current round one reasoning", "Current round two reasoning"]
          results = ["Completed first caller result", "Completed second caller result"]
          token = nil
          DiscourseAi::Completions::Llm.with_prepared_responses(
            [[model_turns[0], calls[0]], [model_turns[1], calls[1]]],
          ) do
            events = collect_events(build_session(topic: topic, query: "Current request"))
            token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
            events =
              collect_events(
                build_session(
                  resume_token: token,
                  tool_results: [{ tool_call_id: calls[0].id, content: results[0] }],
                ),
              )
            token = events.find { |type, _| type == :tool_calls }[1][:resume_token]
          end
          key = described_class.redis_key(token)
          state = JSON.parse(Discourse.redis.get(key))
          if with_checkpoint
            messages = state["prompt"]["messages"]
            state["prompt"]["messages"] = [
              messages.first,
              {
                type: "user",
                content: "<compressed_context>Old historical summary</compressed_context>",
              },
              {
                type: "model",
                content: DiscourseAi::Completions::PromptMessagesBuilder::COMPRESSED_CONTEXT_ACK,
              },
              *messages.drop(state["protected_user_index"]),
            ]
            state["protected_user_index"] = 3
            Discourse.redis.set(key, state.to_json)
          end
          permission_group.remove(admin)
          original = history.raw
          history.update!(raw: "Corrected historical source")

          DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
            expect {
              collect_events(
                build_session(
                  resume_token: token,
                  tool_results: [{ tool_call_id: calls[1].id, content: results[1] }],
                ),
              )
            }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /history_changed/)
            expect(canned.completions).to eq(0)
          end
          reply = topic.posts.order(:post_number).last
          saved = PostCustomPrompt.find_by!(post_id: reply.id).custom_prompt
          expect(saved.select { |entry| entry[2] == "tool" }.map(&:first)).to eq(results)
          expect(saved.select { |entry| entry[2] == "model" }.map(&:first)).to eq(model_turns)
          expect(saved.map { |entry| entry[7] }.uniq).to eq([state["evidence_scope"]])
          expect(saved.to_s).not_to include(original, history.raw, "<compressed_context>")
          expect(Discourse.redis.get(key)).to be_nil
        end
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

    %i[missing extra].each do |invalid_ids|
      it "restores consumed resume state when #{invalid_ids} caller IDs compound a history change" do
        call =
          DiscourseAi::Completions::ToolCall.new(
            id: "compound-read",
            name: "client_tool",
            parameters: {
            },
          )
        token = nil
        DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
          token =
            collect_events(build_session).find { |type, _| type == :tool_calls }[1][:resume_token]
        end
        key = described_class.redis_key(token)
        state = JSON.parse(Discourse.redis.get(key))
        topic = Topic.find(state["topic_id"])
        admin.update!(admin: false, moderator: false)
        topic.topic_allowed_users.where(user_id: admin.id).delete_all
        valid_results = [{ tool_call_id: call.id, content: "Completed result" }]
        invalid_results =
          (
            if invalid_ids == :missing
              []
            else
              valid_results + [{ tool_call_id: "unexpected", content: "Unaccepted result" }]
            end
          )
        DiscourseAi::Completions::Llm.with_prepared_responses([]) do |canned|
          2.times do
            expect {
              collect_events(build_session(resume_token: token, tool_results: invalid_results))
            }.to raise_error(
              described_class::InvalidToolResults,
              I18n.t(
                "discourse_ai.errors.#{invalid_ids == :missing ? "missing" : "unexpected"}_tool_results",
                ids: invalid_ids == :missing ? call.id : "unexpected",
              ),
            )
            expect(JSON.parse(Discourse.redis.get(key))).to eq(state)
            expect(topic.posts.count).to eq(1)
          end
          expect(canned.completions).to eq(0)
        end
        admin.update!(admin: true)
        topic.topic_allowed_users.create!(user_id: admin.id)
        DiscourseAi::Completions::Llm.with_prepared_responses(
          ["Recovered answer", "Title"],
        ) do |_, _, prompts|
          collect_events(build_session(resume_token: token, tool_results: valid_results))
          expect(
            prompts
              .first
              .messages
              .select { |message| message[:type] == :tool }
              .map { |message| message[:content] },
          ).to eq([valid_results.first[:content]])
        end
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
        }.to raise_error(DiscourseAi::Completions::ContextPreparation::Error, /unusable_summary/)
      end
      reply = Post.where(topic_id: topic_id, user: ai_agent.user).last
      expect(reply.raw).to include("Partial answer before the action", "unusable_summary")
      expect(reply.post_custom_prompt.custom_prompt.to_s).to include(result, call.id)
      expect(reply.post_custom_prompt.custom_prompt.to_s).not_to include("<compressed_context>")
      expect(described_class.resume_state_exists?(token)).to eq(false)
    end

    it "restores the cumulative maintenance time and call limit rather than refreshing them on resume" do
      llm.update!(max_prompt_tokens: 16_000)
      call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
          },
          id: "resume-budget",
        )
      token = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([call]) do
        token =
          collect_events(build_session).find { |type, _| type == :tool_calls }[1][:resume_token]
      end
      key = described_class.redis_key(token)
      state = JSON.parse(Discourse.redis.get(key))
      expect(state["preparation_elapsed_seconds"]).to eq(0)
      state["preparation_calls"] = 8
      state["preparation_elapsed_seconds"] = 80
      Discourse.redis.set(key, state.to_json)
      DiscourseAi::Completions::Llm.with_prepared_responses(["unused"]) do |_, _, _, options|
        expect {
          collect_events(
            build_session(
              resume_token: token,
              tool_results: [{ tool_call_id: call.id, content: "Oversized result " * 6000 }],
            ),
          )
        }.to raise_error(
          DiscourseAi::Completions::ContextPreparation::Error,
          /preparation_budget_exhausted/,
        )
        expect(options.none? { |option| option[:feature_name] == "context_compression" }).to eq(
          true,
        )
      end
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
        expect(state["preparation_calls"]).to eq(1)
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
        user_messages = prompts[3].messages.select { |message| message[:type] == :user }
        expect(user_messages.map { |message| message[:content] }).to include(
          "Remember QUARTZ-OTTER-731 and read",
          DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT,
        )
        reply = Post.where(user_id: ai_agent.user_id).order(:id).last
        expect(reply.post_custom_prompt.custom_prompt.flatten.grep(String).join).not_to include(
          DiscourseAi::Agents::Bot::TOKEN_BUDGET_FINAL_ANSWER_HINT,
        )
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
    it "does not replay an incomplete reasoning-only response before the final answer" do
      ai_agent.update!(max_turn_tokens: 3000)
      llm.update!(max_output_tokens: 4000)
      thinking = DiscourseAi::Completions::Thinking.new(message: "Unfinished reasoning")
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [[thinking], "Final answer", "Title"],
      ) do |canned|
        allow(canned).to receive(:output_limit_reached?).and_return(true, false)
        sent_messages = []
        allow(canned).to receive(
          :perform_completion!,
        ).and_wrap_original do |method, dialect, *args, **options, &block|
          sent_messages << dialect.prompt.messages.deep_dup
          method.call(dialect, *args, **options, &block)
        end
        collect_events(build_session)
        expect(sent_messages.second.select { |message| message[:type] == :model }).to be_empty
      end
    end

    it "appends one continuation to a budget-limited caller-tool response" do
      ai_agent.update!(max_turn_tokens: 3000)
      llm.update!(max_output_tokens: 4000)
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["Partial ", "Partial answer", "Title"],
      ) do |canned, _, prompts|
        allow(canned).to receive(:output_limit_reached?).and_return(true, false)
        events = collect_events(build_session)
        expect(events.select { |type, _| type == :partial }.map(&:last).join).to eq(
          "Partial answer",
        )
        expect(events.select { |type, _| type == :tool_calls }).to be_empty
        expect(prompts.second.tool_choice).to eq(:none)
        reply = Post.where(user_id: ai_agent.user_id).order(:id).last
        expect(reply.raw).to include("Partial answer")
        expect(
          reply
            .post_custom_prompt
            .custom_prompt
            .select { |entry| entry[2] == "model" }
            .map(&:first),
        ).to eq(["Partial answer"])
        expect(reply.post_custom_prompt.custom_prompt.flatten.grep(String).join).not_to include(
          DiscourseAi::Completions::ResponseContinuation::INSTRUCTION,
        )
      end
    end

    it "hands a batch of 50 caller tools out for execution" do
      calls =
        50.times.map do |index|
          DiscourseAi::Completions::ToolCall.new(
            id: "batch-#{index}",
            name: "client_tool",
            parameters: {
              input: "read",
            },
          )
        end

      DiscourseAi::Completions::Llm.with_prepared_responses([calls]) do
        events = collect_events(build_session)
        payload = events.find { |type, _| type == :tool_calls }.last

        expect(payload[:tool_calls].map { |call| call[:id] }).to eq(calls.map(&:id))
        expect(described_class.resume_state_exists?(payload[:resume_token])).to eq(true)
      end
    end

    it "rejects a surplus caller batch with one bounded set of wrappers and one final answer" do
      calls =
        52.times.map do |index|
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
        expect(wrappers.size).to eq(52)
        expect(wrappers.map { |message| JSON.parse(message[:content])["error"] }.uniq).to eq(
          ["Not executed — work allowance or tool batch limit reached."],
        )
        expect(final.tool_choice).to eq(:none)
        expect(options[1][:max_tokens]).to eq(2048)
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
        ).to eq([2000, 2048])
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
        [100, 20_000, 4096],
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
        second = JSON.parse(Discourse.redis.get(described_class.redis_key(token)))
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
            resume_token: event[1][:resume_token],
            tool_results: [{ tool_call_id: "reused-id", content: result }],
          ),
        )
        expect(described_class.resume_state_exists?(token)).to eq(false)
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

    it "finishes a resumed turn when its remaining work cannot fit a final answer" do
      llm.update!(provider: "open_ai", url: "https://api.openai.com/v1/responses")
      tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "client_tool",
          parameters: {
            input: "read",
          },
          id: "read",
        )
      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_call, "Complete final answer", "Test title"],
      ) do |_, _, prompts, options|
        event = collect_events(build_session).find { |type, _| type == :tool_calls }
        resume_token = event[1][:resume_token]
        key = described_class.redis_key(resume_token)
        state = JSON.parse(Discourse.redis.get(key))
        state["work_budget"]["used"] = 4990
        Discourse.redis.setex(key, described_class::RESUME_STATE_TTL_SECONDS, state.to_json)

        events =
          collect_events(
            build_session(
              resume_token: resume_token,
              tool_results: [{ tool_call_id: "read", content: "Read result" }],
            ),
          )

        expect(events.select { |type, _| type == :partial }.map(&:last).join).to eq(
          "Complete final answer",
        )
        expect(events.select { |type, _| type == :tool_calls }).to be_empty
        expect(prompts.second.tool_choice).to eq(:none)
        expect(options.second[:max_tokens]).to eq(2048)
        expect(options.second[:thinking_effort]).to eq("none")
      end
    end

    it "triggers synthetic tool errors + final text when budget exhausted mid-round" do
      ai_agent.update!(max_turn_tokens: 2500)

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
            kwargs[:execution_context].work_budget.debit(2500, event_id: SecureRandom.uuid)
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
