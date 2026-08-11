# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:bot_user) { Fabricate(:user, admin: true, refresh_auto_groups: true) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, raw: "bananas are a tasty fruit") }
  fab!(:tag1) { Fabricate(:tag, name: "tag1") }
  fab!(:tag2) { Fabricate(:tag, name: "tag2") }
  fab!(:category) { Fabricate(:category, name: "Test Category", slug: "test-category") }
  fab!(:pm_topic, :private_message_topic)

  fab!(:tool) do
    AiTool.create!(
      name: "test_tool",
      tool_name: "test_tool",
      description: "a test tool",
      script: "function invoke(params) { return { result: 'ok' }; }",
      summary: "test",
      created_by: user,
    )
  end

  def create_tool(script:)
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      script: script,
      created_by_id: 1,
      summary: "Test tool summary",
    )
  end

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
  end

  describe "Discourse operations" do
    context "when using the topic API" do
      it "can fetch topic details" do
        script = <<~JS
          function invoke(params) {
            return discourse.getTopic(params.topic_id);
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({ "topic_id" => topic.id }, llm: nil, bot_user: nil)

        result = runner.invoke

        expect(result["id"]).to eq(topic.id)
        expect(result["title"]).to eq(topic.title)
        expect(result["archetype"]).to eq("regular")
        expect(result["posts_count"]).to eq(1)
      end

      it "can get a topic with tags and first_post_id" do
        tag = Fabricate(:tag, name: "test_tag")
        topic_with_category = Fabricate(:topic, category: category)
        Fabricate(:post, topic: topic_with_category)
        topic_with_category.tags << tag

        tool.update!(
          script:
            "function invoke(params) { const t = discourse.getTopic(params.topic_id); return { tags: t.tags, first_post_id: t.first_post_id }; }",
        )
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["tags"]).to contain_exactly("test_tag")
        expect(result["first_post_id"]).to eq(topic_with_category.first_post.id)
      end

      it "can get a topic with category info" do
        topic_with_category = Fabricate(:topic, category: category)
        tool.update!(script: <<~JS)
            function invoke(params) {
              const t = discourse.getTopic(params.topic_id);
              return {
                category_id: t.category_id,
                category_name: t.category_name,
                category_slug: t.category_slug
              };
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["category_id"]).to eq(category.id)
        expect(result["category_name"]).to eq("Test Category")
        expect(result["category_slug"]).to eq("test-category")
      end

      it "fetches an exact post by topic coordinates, including restricted topics" do
        reply = Fabricate(:post, topic: topic)
        private_post = Fabricate(:post, topic: pm_topic)
        tool.update!(script: <<~JS)
            function invoke(params) {
              return {
                exact: discourse.getTopicPost(params.topic_id, params.post_number),
                missing: discourse.getTopicPost(params.topic_id, 999999),
                privatePost: discourse.getTopicPost(params.private_topic_id, params.private_post_number)
              };
            }
          JS

        result =
          tool.runner(
            {
              "topic_id" => topic.id,
              "post_number" => reply.post_number,
              "private_topic_id" => pm_topic.id,
              "private_post_number" => private_post.post_number,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["exact"].slice("id", "topic_id", "post_number", "raw")).to eq(
          "id" => reply.id,
          "topic_id" => topic.id,
          "post_number" => reply.post_number,
          "raw" => reply.raw,
        )
        expect(result["exact"].dig("topic", "id")).to eq(topic.id)
        expect(result["missing"]).to be_nil
        expect(result["privatePost"]["id"]).to eq(private_post.id)
      end

      it "accepts null options and rejects malformed topic coordinates" do
        tool.update!(script: <<~JS)
            function errorMessage(callback) {
              try {
                callback();
              } catch (error) {
                return error.message;
              }
            }

            function invoke(params) {
              return {
                nullOptions: discourse.getTopicPost(
                  params.topic_id,
                  params.post_number,
                  null
                ),
                invalidTopicId: errorMessage(function() {
                  discourse.getTopicPost("2abc", params.post_number);
                }),
                invalidPostNumber: errorMessage(function() {
                  discourse.getTopicPost(params.topic_id, 2.9);
                })
              };
            }
          JS

        result =
          tool.runner(
            { "topic_id" => topic.id, "post_number" => post.post_number },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["nullOptions"]["id"]).to eq(post.id)
        expect(result["invalidTopicId"]).to eq("topic_id must be a positive integer")
        expect(result["invalidPostNumber"]).to eq("post_number must be a positive integer")
      end

      it "fetches bounded topic posts and can filter by post number" do
        replies = Fabricate.times(3, :post, topic: topic)
        tool.update!(script: <<~JS)
            function invoke(params) {
              return {
                limited: discourse.getTopicPosts(params.topic_id, { limit: 2 }),
                selected: discourse.getTopicPosts(params.topic_id, {
                  post_numbers: params.post_numbers
                }),
                missing: discourse.getTopicPosts(999999)
              };
            }
          JS

        selected_post_numbers = [replies.second.post_number, post.post_number]
        result =
          tool.runner(
            { "topic_id" => topic.id, "post_numbers" => selected_post_numbers },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["limited"].map { |item| item["post_number"] }).to eq([1, 2])
        expect(result["selected"].map { |item| item["post_number"] }).to eq(
          selected_post_numbers.sort,
        )
        expect(result["missing"]).to eq([])
      end

      it "scopes topic post reads through a specified user's Guardian" do
        group = Fabricate(:group)
        allowed_user = Fabricate(:user)
        denied_user = Fabricate(:user)
        staged_user = Fabricate(:staged)
        group.add(allowed_user)
        private_category = Fabricate(:private_category, group: group)
        private_topic = Fabricate(:topic, category: private_category)
        private_post = Fabricate(:post, topic: private_topic)

        tool.update!(script: <<~JS)
            function invoke(params) {
              return {
                allowed: discourse.getTopicPost(params.topic_id, params.post_number, {
                  as_username: params.allowed_username
                }),
                allowedById: discourse.getTopicPost(params.topic_id, params.post_number, {
                  as_user_id: params.allowed_user_id
                }),
                denied: discourse.getTopicPost(params.topic_id, params.post_number, {
                  as_user_id: params.denied_user_id
                }),
                staged: discourse.getTopicPost(params.topic_id, params.post_number, {
                  as_user_id: params.staged_user_id
                }),
                deniedTopicPosts: discourse.getTopicPosts(params.topic_id, {
                  as_user_id: params.denied_user_id
                })
              };
            }
          JS

        result =
          tool.runner(
            {
              "topic_id" => private_topic.id,
              "post_number" => private_post.post_number,
              "allowed_username" => allowed_user.username.upcase,
              "allowed_user_id" => allowed_user.id,
              "denied_user_id" => denied_user.id,
              "staged_user_id" => staged_user.id,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["allowed"]["id"]).to eq(private_post.id)
        expect(result["allowedById"]["id"]).to eq(private_post.id)
        expect(result["denied"]).to be_nil
        expect(result["staged"]).to be_nil
        expect(result["deniedTopicPosts"]).to eq([])
      end

      it "omits hidden posts and whispers from Guardian-scoped topic collections" do
        reader = Fabricate(:user)
        visible_post = Fabricate(:post, topic: topic)
        hidden_post = Fabricate(:post, topic: topic, hidden: true)
        whisper = Fabricate(:whisper, topic: topic)

        tool.update!(script: <<~JS)
            function invoke(params) {
              return {
                collection: discourse.getTopicPosts(params.topic_id, {
                  as_user_id: params.user_id,
                  post_numbers: params.post_numbers
                }),
                exact: discourse.getTopicPost(params.topic_id, params.hidden_post_number, {
                  as_user_id: params.user_id
                })
              };
            }
          JS

        result =
          tool.runner(
            {
              "topic_id" => topic.id,
              "user_id" => reader.id,
              "post_numbers" => [
                visible_post.post_number,
                hidden_post.post_number,
                whisper.post_number,
              ],
              "hidden_post_number" => hidden_post.post_number,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["collection"].map { |item| item["id"] }).to eq([visible_post.id])
        expect(result["exact"]).to be_nil
      end

      it "scopes private message collections to participants" do
        sender = Fabricate(:user)
        recipient = Fabricate(:user)
        outsider = Fabricate(:user)
        private_message = Fabricate(:private_message_topic, user: sender, recipient: recipient)
        private_post = Fabricate(:post, topic: private_message, user: sender)

        tool.update!(script: <<~JS)
            function invoke(params) {
              return {
                participant: discourse.getTopicPosts(params.topic_id, {
                  as_user_id: params.participant_id
                }),
                outsider: discourse.getTopicPosts(params.topic_id, {
                  as_user_id: params.outsider_id
                })
              };
            }
          JS

        result =
          tool.runner(
            {
              "topic_id" => private_message.id,
              "participant_id" => recipient.id,
              "outsider_id" => outsider.id,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["participant"].map { |item| item["id"] }).to eq([private_post.id])
        expect(result["outsider"]).to eq([])
      end

      it "rejects invalid and unsupported read scope options" do
        scenarios = [
          ["Unsupported option", '{ as_usernme: "validator" }'],
          ["cannot be used together", '{ as_username: "validator", as_user_id: 1 }'],
          ["as_username must be a non-empty string", '{ as_username: "" }'],
          [
            "as_username must identify a user with a positive ID",
            "{ as_username: #{::Discourse.system_user.username.to_json} }",
          ],
          ["User not found", "{ as_user_id: 99999999 }"],
          ["positive integer", "{ as_user_id: -1 }"],
          ["options must be an object", '"validator"'],
        ]

        scenarios.each do |expected_error, options|
          tool.update!(script: <<~JS)
              function invoke(params) {
                try {
                  discourse.getTopicPost(params.topic_id, params.post_number, #{options});
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS

          result =
            tool.runner(
              { "topic_id" => topic.id, "post_number" => post.post_number },
              llm: nil,
              bot_user: nil,
            ).invoke

          expect(result["error"]).to match(/#{expected_error}/)
        end
      end

      it "caps topic post limits and rejects oversized selections" do
        Fabricate.times(20, :post, topic: topic)
        tool.update!(script: <<~JS)
            function invoke(params) {
              const oversizedLimit = discourse.getTopicPosts(params.topic_id, {
                limit: 100000
              });
              try {
                discourse.getTopicPosts(params.topic_id, {
                  post_numbers: params.post_numbers
                });
              } catch (error) {
                return { oversizedLimit, selectionError: error.message };
              }
            }
          JS

        post_numbers = topic.posts.order(:post_number).pluck(:post_number)
        result =
          tool.runner(
            { "topic_id" => topic.id, "post_numbers" => post_numbers },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["oversizedLimit"].size).to eq(20)
        expect(result["selectionError"]).to eq("post_numbers cannot exceed 20 entries")
      end

      it "rejects malformed and conflicting topic post collection options" do
        scenarios = [
          ["post_numbers must be an array", '{ post_numbers: "1,2" }'],
          ["post_numbers must contain positive integers", '{ post_numbers: [1, "2"] }'],
          ["limit must be a positive integer", '{ limit: "20" }'],
          ["limit must be a positive integer", "{ limit: 0 }"],
          ["limit must be a positive integer", "{ limit: -1 }"],
          ["limit and post_numbers cannot be used together", "{ limit: 1, post_numbers: [1] }"],
        ]

        scenarios.each do |expected_error, options|
          tool.update!(script: <<~JS)
              function invoke(params) {
                try {
                  discourse.getTopicPosts(params.topic_id, #{options});
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS
          result = tool.runner({ "topic_id" => topic.id }, llm: nil, bot_user: nil).invoke

          expect(result["error"]).to match(/#{expected_error}/)
        end
      end
    end

    context "when using the topic filter API" do
      it "filters topics matching the query and returns serialized fields" do
        matching_topic =
          Fabricate(:topic, category: category, title: "NDA checklist guidance topic")
        matching_post = Fabricate(:post, topic: matching_topic, raw: "NDA checklist details")
        matching_topic.tags << tag1
        other_matching_topic =
          Fabricate(:topic, category: category, title: "How to review a contract safely")
        other_matching_post =
          Fabricate(:post, topic: other_matching_topic, raw: "Contract review details")
        Fabricate(:topic, title: "Outside category knowledge topic")

        script = <<~JS
          function invoke(params) {
            return discourse.filterTopics({
              q: "category:" + params.category,
              limit: params.limit
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner({ "category" => category.slug, "limit" => 10 }, llm: nil, bot_user: nil)

        result = runner.invoke
        topics = result["topics"]

        expect(result["query"]).to eq("category:#{category.slug}")
        expect(result["limit"]).to eq(10)
        expect(topics.map { |topic| topic["id"] }).to contain_exactly(
          matching_topic.id,
          other_matching_topic.id,
        )
        expect(topics.map { |topic| topic["category_slug"] }.uniq).to eq([category.slug])
        expect(topics.map { |topic| topic["first_post_id"] }).to contain_exactly(
          matching_post.id,
          other_matching_post.id,
        )
        expect(topics.find { |topic| topic["id"] == matching_topic.id }["tags"]).to contain_exactly(
          tag1.name,
        )
      end

      it "respects the limit parameter" do
        3.times do |i|
          Fabricate(:topic, category: category, title: "Legal knowledge topic number #{i}")
        end

        script = <<~JS
          function invoke(params) {
            return discourse.filterTopics({ q: params.q, limit: params.limit });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner({ "q" => "category:#{category.slug}", "limit" => 2 }, llm: nil, bot_user: nil)

        result = runner.invoke
        oversized_result =
          tool.runner(
            { "q" => "category:#{category.slug}", "limit" => 100_000 },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["topics"].size).to eq(2)
        expect(oversized_result["limit"]).to eq(100)
      end

      it "returns catchable errors for invalid filter parameters" do
        script = <<~JS
          function errorMessage(callback) {
            try {
              callback();
            } catch (error) {
              return error.message;
            }
          }

          function invoke(params) {
            return {
              missingQuery: errorMessage(function() {
                discourse.filterTopics({});
              }),
              negativePage: errorMessage(function() {
                discourse.filterTopics({ q: "order:latest", page: -1 });
              }),
              malformedPage: errorMessage(function() {
                discourse.filterTopics({ q: "order:latest", page: "1" });
              }),
              unknownOption: errorMessage(function() {
                discourse.filterTopics({ q: "order:latest", unexpected: true });
              }),
              scopeConflict: errorMessage(function() {
                discourse.filterTopics({
                  q: "order:latest",
                  as_user_id: params.user_id,
                  with_private: false
                });
              })
            };
          }
        JS

        result =
          create_tool(script: script).runner(
            { "user_id" => user.id },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result).to eq(
          "missingQuery" => "Missing required parameter: q",
          "negativePage" => "page must be greater than or equal to 0",
          "malformedPage" => "page must be greater than or equal to 0",
          "unknownOption" => "Unsupported option(s): unexpected",
          "scopeConflict" => "with_private cannot be used with as_username or as_user_id",
        )
      end

      it "applies authenticated topic filters as the scoped user" do
        scoped_user = Fabricate(:user)
        tracked_topic = Fabricate(:topic, category: category)
        Fabricate(:topic_user_tracking, topic: tracked_topic, user: scoped_user)
        Fabricate(:topic, category: category)

        script = <<~JS
          function invoke(params) {
            return {
              byId: discourse.filterTopics({
                q: "in:tracking",
                as_user_id: params.user_id
              }),
              byUsername: discourse.filterTopics({
                q: "in:tracking",
                as_username: params.username
              })
            };
          }
        JS

        result =
          create_tool(script: script).runner(
            { "user_id" => scoped_user.id, "username" => scoped_user.username.upcase },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result.dig("byId", "topics").map { |topic| topic["id"] }).to eq([tracked_topic.id])
        expect(result.dig("byUsername", "topics").map { |topic| topic["id"] }).to eq(
          [tracked_topic.id],
        )
      end

      it "requires with_private to include private categories" do
        private_category =
          Fabricate(
            :private_category,
            group: Fabricate(:group),
            slug: "private-legal-kb",
            name: "Private Legal KB",
          )
        private_topic =
          Fabricate(:topic, category: private_category, title: "Private legal playbook topic")

        script = <<~JS
          function invoke(params) {
            return discourse.filterTopics({
              q: "category:" + params.category,
              with_private: params.with_private
            });
          }
        JS

        tool = create_tool(script: script)

        public_result =
          tool.runner({ "category" => private_category.slug }, llm: nil, bot_user: nil).invoke
        private_result =
          tool.runner(
            { "category" => private_category.slug, "with_private" => true },
            llm: nil,
            bot_user: nil,
          ).invoke
        string_private_result =
          tool.runner(
            { "category" => private_category.slug, "with_private" => "true" },
            llm: nil,
            bot_user: nil,
          ).invoke
        string_public_result =
          tool.runner(
            { "category" => private_category.slug, "with_private" => "false" },
            llm: nil,
            bot_user: nil,
          ).invoke
        empty_string_public_result =
          tool.runner(
            { "category" => private_category.slug, "with_private" => "" },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(public_result["topics"]).to eq([])
        expect(private_result["topics"].map { |topic| topic["id"] }).to eq([private_topic.id])
        expect(string_private_result["topics"].map { |topic| topic["id"] }).to eq(
          [private_topic.id],
        )
        expect(string_public_result["topics"]).to eq([])
        expect(empty_string_public_result["topics"]).to eq([])
      end

      it "scopes filtered topics through a stable user ID" do
        group = Fabricate(:group)
        allowed_user = Fabricate(:user)
        denied_user = Fabricate(:user)
        group.add(allowed_user)
        private_category = Fabricate(:private_category, group: group)
        private_topic = Fabricate(:topic, category: private_category)

        script = <<~JS
          function invoke(params) {
            const query = "category:" + params.category;
            return {
              allowed: discourse.filterTopics({
                q: query,
                as_user_id: params.allowed_user_id
              }),
              denied: discourse.filterTopics({
                q: query,
                as_user_id: params.denied_user_id
              })
            };
          }
        JS

        tool = create_tool(script: script)
        result =
          tool.runner(
            {
              "category" => private_category.slug,
              "allowed_user_id" => allowed_user.id,
              "denied_user_id" => denied_user.id,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result.dig("allowed", "topics").map { |topic| topic["id"] }).to eq(
          [private_topic.id],
        )
        expect(result.dig("denied", "topics")).to eq([])
      end
    end

    context "when using the post API" do
      it "can fetch post details" do
        script = <<~JS
          function invoke(params) {
            const post = discourse.getPost(params.post_id);
            return {
              post: post,
              topic: post.topic
            }
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({ "post_id" => post.id }, llm: nil, bot_user: nil)

        result = runner.invoke
        post_hash = result["post"]
        topic_hash = result["topic"]

        expect(post_hash["id"]).to eq(post.id)
        expect(post_hash["topic_id"]).to eq(topic.id)
        expect(post_hash["raw"]).to eq(post.raw)

        expect(topic_hash["id"]).to eq(topic.id)
      end

      it "scopes getPost and getTopic through a stable user ID" do
        group = Fabricate(:group)
        allowed_user = Fabricate(:user)
        denied_user = Fabricate(:user)
        group.add(allowed_user)
        private_category = Fabricate(:private_category, group: group)
        private_topic = Fabricate(:topic, category: private_category)
        private_post = Fabricate(:post, topic: private_topic)

        script = <<~JS
          function invoke(params) {
            return {
              legacyPost: discourse.getPost(params.post_id),
              legacyTopic: discourse.getTopic(params.topic_id),
              allowedPost: discourse.getPost(params.post_id, {
                as_user_id: params.allowed_user_id
              }),
              deniedPost: discourse.getPost(params.post_id, {
                as_user_id: params.denied_user_id
              }),
              allowedTopic: discourse.getTopic(params.topic_id, {
                as_user_id: params.allowed_user_id
              }),
              deniedTopic: discourse.getTopic(params.topic_id, {
                as_user_id: params.denied_user_id
              })
            };
          }
        JS

        tool = create_tool(script: script)
        result =
          tool.runner(
            {
              "post_id" => private_post.id,
              "topic_id" => private_topic.id,
              "allowed_user_id" => allowed_user.id,
              "denied_user_id" => denied_user.id,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["legacyPost"]["id"]).to eq(private_post.id)
        expect(result["legacyTopic"]["id"]).to eq(private_topic.id)
        expect(result["allowedPost"]["id"]).to eq(private_post.id)
        expect(result["deniedPost"]).to be_nil
        expect(result["allowedTopic"]["id"]).to eq(private_topic.id)
        expect(result["deniedTopic"]).to be_nil
      end
    end

    context "when using the search API" do
      before { SearchIndexer.enable }
      after { SearchIndexer.disable }

      it "can perform a discourse search" do
        SearchIndexer.index(topic, force: true)
        SearchIndexer.index(post, force: true)

        script = <<~JS
          function invoke(params) {
            return discourse.search({
              search_query: params.query,
              result_style: "compact"
            });
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({ "query" => "banana" }, llm: nil, bot_user: nil)

        result = runner.invoke

        expect(result["rows"].length).to be > 0
        expect(result["rows"].first["title"]).to eq(topic.title)
      end

      it "scopes search through a specified user's Guardian" do
        group = Fabricate(:group)
        allowed_user = Fabricate(:user)
        denied_user = Fabricate(:user)
        group.add(allowed_user)
        private_category = Fabricate(:private_category, group: group)
        private_topic = Fabricate(:topic, category: private_category)
        private_post = Fabricate(:post, topic: private_topic, raw: "private validator needlephrase")
        SearchIndexer.index(private_post, force: true)

        script = <<~JS
          function invoke(params) {
            return {
              system: discourse.search({
                search_query: params.query,
                with_private: true
              }),
              allowed: discourse.search({
                search_query: params.query,
                as_user_id: params.allowed_user_id
              }),
              denied: discourse.search({
                search_query: params.query,
                as_user_id: params.denied_user_id
              })
            };
          }
        JS

        tool = create_tool(script: script)
        result =
          tool.runner(
            {
              "query" => "private validator needlephrase",
              "allowed_user_id" => allowed_user.id,
              "denied_user_id" => denied_user.id,
            },
            llm: nil,
            bot_user: nil,
          ).invoke

        expect(result["system"]["rows"].map { |row| row["title"] }).to eq([private_topic.title])
        expect(result["allowed"]["rows"].map { |row| row["title"] }).to eq([private_topic.title])
        expect(result["denied"]["rows"]).to eq([])
      end

      it "rejects conflicting and unknown search scope options" do
        scripts = [
          ["cannot be used", <<~JS],
              function invoke(params) {
                try {
                  discourse.search({
                    search_query: "banana",
                    as_user_id: params.user_id,
                    with_private: false
                  });
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS
          ["Unsupported option", <<~JS],
              function invoke(params) {
                try {
                  discourse.search({
                    search_query: "banana",
                    as_user: params.user_id
                  });
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS
          ["with_private must be a boolean", <<~JS],
              function invoke() {
                try {
                  discourse.search({
                    search_query: "banana",
                    with_private: "yes"
                  });
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS
          ["max_results must be a positive integer", <<~JS],
              function invoke() {
                try {
                  discourse.search({
                    search_query: "banana",
                    max_results: 0
                  });
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS
          ["options must be an object", <<~JS],
              function invoke() {
                try {
                  discourse.search(null);
                } catch (error) {
                  return { error: error.message };
                }
              }
            JS
        ]

        scripts.each do |expected_error, script|
          tool = create_tool(script: script)
          result = tool.runner({ "user_id" => user.id }, llm: nil, bot_user: nil).invoke

          expect(result["error"]).to match(/#{expected_error}/)
        end
      end
    end

    context "when using the chat API" do
      before(:each) do
        skip "Chat plugin tests skipped because Chat module is not defined." unless defined?(Chat)
        SiteSetting.chat_enabled = true
      end

      fab!(:chat_user, :user)
      fab!(:chat_channel) do
        Fabricate(:chat_channel).tap do |channel|
          Fabricate(
            :user_chat_channel_membership,
            user: chat_user,
            chat_channel: channel,
            following: true,
          )
        end
      end

      it "can create a chat message" do
        script = <<~JS
          function invoke(params) {
            return discourse.createChatMessage({
              channel_name: params.channel_name,
              username: params.username,
              message: params.message
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            {
              "channel_name" => chat_channel.name,
              "username" => chat_user.username,
              "message" => "Hello from the tool!",
            },
            llm: nil,
            bot_user: bot_user,
          )

        initial_message_count = Chat::Message.count
        result = runner.invoke

        expect(result["success"]).to eq(true), "Tool invocation failed: #{result["error"]}"
        expect(result["message"]).to eq("Hello from the tool!")
        expect(result["created_at"]).to be_present
        expect(result).not_to have_key("error")

        expect(Chat::Message.count).to eq(initial_message_count + 1)
        created_message = Chat::Message.find_by(id: result["message_id"])

        expect(created_message).not_to be_nil
        expect(created_message.message).to eq("Hello from the tool!")
        expect(created_message.user_id).to eq(chat_user.id)
        expect(created_message.chat_channel_id).to eq(chat_channel.id)
      end

      it "can create a chat message using channel slug" do
        chat_channel.update!(name: "My Test Channel", slug: "my-test-channel")
        expect(chat_channel.slug).to eq("my-test-channel")

        script = <<~JS
          function invoke(params) {
            return discourse.createChatMessage({
              channel_name: params.channel_slug,
              username: params.username,
              message: params.message
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            {
              "channel_slug" => chat_channel.slug,
              "username" => chat_user.username,
              "message" => "Hello via slug!",
            },
            llm: nil,
            bot_user: bot_user,
          )

        result = runner.invoke

        expect(result["success"]).to eq(true), "Tool invocation failed: #{result["error"]}"

        created_message = Chat::Message.find_by(id: result["message_id"])
        expect(created_message).not_to be_nil
        expect(created_message.message).to eq("Hello via slug!")
        expect(created_message.chat_channel_id).to eq(chat_channel.id)
      end

      it "returns an error if the channel is not found" do
        script = <<~JS
          function invoke(params) {
            return discourse.createChatMessage({
              channel_name: "non_existent_channel",
              username: params.username,
              message: params.message
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { "username" => chat_user.username, "message" => "Test" },
            llm: nil,
            bot_user: bot_user,
          )

        initial_message_count = Chat::Message.count
        expect { runner.invoke }.to raise_error(
          MiniRacer::RuntimeError,
          /Channel not found: non_existent_channel/,
        )

        expect(Chat::Message.count).to eq(initial_message_count)
      end

      it "returns an error if the user is not found" do
        script = <<~JS
          function invoke(params) {
            return discourse.createChatMessage({
              channel_name: params.channel_name,
              username: "non_existent_user",
              message: params.message
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { "channel_name" => chat_channel.name, "message" => "Test" },
            llm: nil,
            bot_user: bot_user,
          )

        initial_message_count = Chat::Message.count
        expect { runner.invoke }.to raise_error(
          MiniRacer::RuntimeError,
          /User not found: non_existent_user/,
        )

        expect(Chat::Message.count).to eq(initial_message_count)
      end
    end

    context "when updating agents" do
      fab!(:ai_agent) { Fabricate(:ai_agent, name: "TestAgent", system_prompt: "Original prompt") }

      it "can update a agent with proper permissions" do
        script = <<~JS
          function invoke(params) {
            return discourse.updateAgent(params.agent_name, {
              system_prompt: params.new_prompt,
              temperature: 0.7,
              top_p: 0.9
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { agent_name: "TestAgent", new_prompt: "Updated system prompt" },
            llm: nil,
            bot_user: bot_user,
          )

        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["agent"]["system_prompt"]).to eq("Updated system prompt")
        expect(result["agent"]["temperature"]).to eq(0.7)

        ai_agent.reload
        expect(ai_agent.system_prompt).to eq("Updated system prompt")
        expect(ai_agent.temperature).to eq(0.7)
        expect(ai_agent.top_p).to eq(0.9)
      end
    end

    context "when fetching agent information" do
      fab!(:ai_agent) do
        Fabricate(
          :ai_agent,
          name: "TestAgent",
          description: "Test description",
          system_prompt: "Test system prompt",
          temperature: 0.8,
          top_p: 0.9,
          vision_enabled: true,
          tools: ["Search", ["WebSearch", { param: "value" }, true]],
        )
      end

      it "can fetch a agent by name" do
        script = <<~JS
          function invoke(params) {
            const agent = discourse.getAgent(params.agent_name);
            return agent;
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({ agent_name: "TestAgent" }, llm: nil, bot_user: bot_user)

        result = runner.invoke

        expect(result["id"]).to eq(ai_agent.id)
        expect(result["name"]).to eq("TestAgent")
        expect(result["description"]).to eq("Test description")
        expect(result["system_prompt"]).to eq("Test system prompt")
        expect(result["temperature"]).to eq(0.8)
        expect(result["top_p"]).to eq(0.9)
        expect(result["vision_enabled"]).to eq(true)
        expect(result["tools"]).to include("Search")
        expect(result["tools"][1]).to be_a(Array)
      end

      it "raises an error when the agent doesn't exist" do
        script = <<~JS
          function invoke(params) {
            return discourse.getAgent("NonExistentAgent");
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({}, llm: nil, bot_user: bot_user)

        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Agent not found/)
      end

      it "can update a agent after fetching it" do
        script = <<~JS
          function invoke(params) {
            const agent = discourse.getAgent("TestAgent");
            return agent.update({
              system_prompt: "Updated through getAgent().update()",
              temperature: 0.5
            });
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({}, llm: nil, bot_user: bot_user)

        result = runner.invoke
        expect(result["success"]).to eq(true)

        ai_agent.reload
        expect(ai_agent.system_prompt).to eq("Updated through getAgent().update()")
        expect(ai_agent.temperature).to eq(0.5)
      end
    end

    context "when creating staged users" do
      it "can create a staged user" do
        script = <<~JS
          function invoke(params) {
            return discourse.createStagedUser({
              email: params.email,
              username: params.username,
              name: params.name
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { email: "testuser@example.com", username: "testuser123", name: "Test User" },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result["success"]).to eq(true)
        expect(result["username"]).to eq("testuser123")
        expect(result["email"]).to eq("testuser@example.com")

        user = User.find_by(id: result["user_id"])
        expect(user).not_to be_nil
        expect(user.staged).to eq(true)
        expect(user.username).to eq("testuser123")
        expect(user.email).to eq("testuser@example.com")
        expect(user.name).to eq("Test User")
      end

      it "returns an error if user already exists" do
        existing_user = Fabricate(:user, email: "existing@example.com", username: "existinguser")

        script = <<~JS
          function invoke(params) {
            try {
            return discourse.createStagedUser({
              email: params.email,
              username: params.username
            });
            } catch (e) {
              return { error: e.message };
            }
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { email: existing_user.email, username: "newusername" },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result["error"]).to eq("User already exists")
      end
    end

    context "when creating topics" do
      it "can create a topic" do
        script = <<~JS
          function invoke(params) {
            return discourse.createTopic({
              category_id: params.category_id,
              title: params.title,
              raw: params.raw,
              username: params.username,
              tags: params.tags
            });
          }
        JS

        admin = Fabricate(:admin)
        tool = create_tool(script: script)
        runner =
          tool.runner(
            {
              category_id: category.id,
              title: "Test Topic Title",
              raw: "This is the content of the test topic",
              username: admin.username,
              tags: %w[test example],
            },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result["success"]).to eq(true)
        expect(result["topic_id"]).to be_present
        expect(result["post_id"]).to be_present

        new_topic = Topic.find_by(id: result["topic_id"])
        expect(new_topic).not_to be_nil
        expect(new_topic.title).to eq("Test Topic Title")
        expect(new_topic.category_id).to eq(category.id)
        expect(new_topic.user_id).to eq(admin.id)
        expect(new_topic.archetype).to eq("regular")
        expect(new_topic.tags.pluck(:name)).to contain_exactly("test", "example")

        new_post = Post.find_by(id: result["post_id"])
        expect(new_post).not_to be_nil
        expect(new_post.raw).to eq("This is the content of the test topic")
      end

      it "can create a topic without username (uses system user)" do
        script = <<~JS
          function invoke(params) {
            return discourse.createTopic({
              category_id: params.category_id,
              title: params.title,
              raw: params.raw
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { category_id: category.id, title: "System User Topic", raw: "Created by system" },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result["success"]).to eq(true)

        new_topic = Topic.find_by(id: result["topic_id"])
        expect(new_topic.user_id).to eq(Discourse.system_user.id)
      end

      it "returns an error for invalid category" do
        script = <<~JS
          function invoke(params) {
            return discourse.createTopic({
              category_id: 99999,
              title: "Test",
              raw: "Test"
            });
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({}, llm: nil, bot_user: nil)

        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Category not found/)
      end
    end

    context "when creating posts" do
      fab!(:topic_for_posts) { Fabricate(:post).topic }

      it "can create a post in a topic" do
        script = <<~JS
          function invoke(params) {
            return discourse.createPost({
              topic_id: params.topic_id,
              raw: params.raw,
              username: params.username
            });
          }
        JS

        regular_user = Fabricate(:user)
        tool = create_tool(script: script)
        runner =
          tool.runner(
            {
              topic_id: topic_for_posts.id,
              raw: "This is a reply to the topic",
              username: regular_user.username,
            },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result["success"]).to eq(true)
        expect(result["post_id"]).to be_present
        expect(result["post_number"]).to be > 1

        new_post = Post.find_by(id: result["post_id"])
        expect(new_post).not_to be_nil
        expect(new_post.raw).to eq("This is a reply to the topic")
        expect(new_post.topic_id).to eq(topic_for_posts.id)
        expect(new_post.user_id).to eq(regular_user.id)
      end

      it "can create a reply to a specific post" do
        _original_post = Fabricate(:post, topic: topic_for_posts, post_number: 2)

        script = <<~JS
          function invoke(params) {
            return discourse.createPost({
              topic_id: params.topic_id,
              raw: params.raw,
              reply_to_post_number: params.reply_to_post_number
            });
          }
        JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            {
              topic_id: topic_for_posts.id,
              raw: "This is a reply to post #2",
              reply_to_post_number: 2,
            },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result["success"]).to eq(true)

        new_post = Post.find_by(id: result["post_id"])
        expect(new_post.reply_to_post_number).to eq(2)
      end

      it "returns an error for invalid topic" do
        script = <<~JS
          function invoke(params) {
            return discourse.createPost({
              topic_id: 99999,
              raw: "Test"
            });
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({}, llm: nil, bot_user: nil)

        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Topic not found/)
      end
    end

    context "when seeding a category with topics" do
      it "can seed a category with a topic and post" do
        script = <<~JS
          function invoke(params) {
            const user = discourse.createStagedUser({
              email: 'testuser@example.com',
              username: 'testuser',
              name: 'Test User'
            });

            const topic = discourse.createTopic({
              category_name: params.category_name,
              title: 'Test Topic 123 123 123',
              raw: 'This is the initial post content.',
              username: user.username
            });

            const post = discourse.createPost({
              topic_id: topic.topic_id,
              raw: 'This is a reply to the topic.',
              username: user.username
            });

            return {
              success: true,
              user: user,
              topic: topic,
              post: post
            };
          }
        JS

        tool = create_tool(script: script)
        runner = tool.runner({ category_name: category.name }, llm: nil, bot_user: nil)

        result = runner.invoke

        expect(result["success"]).to eq(true)

        seeded_user = User.find_by(username: "testuser")
        expect(seeded_user).not_to be_nil
        expect(seeded_user.staged).to eq(true)

        seeded_topic = Topic.find_by(id: result["topic"]["topic_id"])
        expect(seeded_topic).not_to be_nil
        expect(seeded_topic.category_id).to eq(category.id)

        expect(seeded_topic.posts.count).to eq(2)
      end
    end

    describe "editTopic" do
      fab!(:topic_with_category) { Fabricate(:topic, category: category) }

      it "can set tags on a topic" do
        tool.update!(
          script:
            "function invoke(params) { return discourse.editTopic(params.topic_id, { tags: ['tag1', 'tag2'] }); }",
        )
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["tags"]).to contain_exactly("tag1", "tag2")
        expect(topic_with_category.reload.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
      end

      it "can append tags on a topic" do
        old_tag = Fabricate(:tag, name: "old_tag")
        topic_with_category.tags << old_tag
        Fabricate(:tag, name: "new_tag")
        tool.update!(
          script:
            "function invoke(params) { return discourse.editTopic(params.topic_id, { tags: ['new_tag'] }, { append: true }); }",
        )
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(topic_with_category.reload.tags.pluck(:name)).to contain_exactly(
          "old_tag",
          "new_tag",
        )
      end

      it "can set tags as a specific user" do
        tool.update!(
          script:
            "function invoke(params) { return discourse.editTopic(params.topic_id, { tags: ['tag1'] }, { username: 'system' }); }",
        )
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["tags"]).to eq(["tag1"])
        expect(topic_with_category.reload.tags.pluck(:name)).to contain_exactly("tag1")
      end

      it "publishes to MessageBus when setting tags" do
        mb_topic = Fabricate(:topic)
        Fabricate(:post, topic: mb_topic)
        Fabricate(:tag, name: "msgbus_tag")
        tool.update!(
          script:
            "function invoke(params) { return discourse.setTags(params.topic_id, ['msgbus_tag']); }",
        )

        messages =
          MessageBus.track_publish("/topic/#{mb_topic.id}") do
            runner =
              described_class.new(
                parameters: {
                  topic_id: mb_topic.id,
                },
                llm: llm,
                bot_user: bot_user,
                tool: tool,
              )
            result = runner.invoke
            expect(result["success"]).to eq(true)
          end

        expect(messages).not_to be_empty
        expect(messages.first.data[:type]).to eq(:revised)
      end

      it "can set category on a topic by slug" do
        new_category = Fabricate(:category, slug: "new-category")
        tool.update!(script: <<~JS)
            function invoke(params) {
              return discourse.editTopic(params.topic_id, { category: "new-category" });
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["category_id"]).to eq(new_category.id)
        expect(topic_with_category.reload.category_id).to eq(new_category.id)
      end

      it "can set category on a topic by ID" do
        new_category = Fabricate(:category)
        tool.update!(script: <<~JS)
            function invoke(params) {
              return discourse.editTopic(params.topic_id, { category: params.category_id });
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
              category_id: new_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["category_id"]).to eq(new_category.id)
        expect(topic_with_category.reload.category_id).to eq(new_category.id)
      end

      it "can set category on a topic by name" do
        new_category = Fabricate(:category, name: "New Category Name", slug: "different-slug")
        tool.update!(script: <<~JS)
            function invoke(params) {
              return discourse.editTopic(params.topic_id, { category: "New Category Name" });
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["category_id"]).to eq(new_category.id)
        expect(topic_with_category.reload.category_id).to eq(new_category.id)
      end

      it "returns error when setting category on private message" do
        tool.update!(script: <<~JS)
            function invoke(params) {
              try {
                return discourse.editTopic(params.topic_id, { category: params.category_id });
              } catch(e) {
                return { error: e.message };
              }
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: pm_topic.id,
              category_id: category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["error"]).to include("private")
      end

      it "can unlist a topic" do
        tool.update!(script: <<~JS)
            function invoke(params) {
              return discourse.editTopic(params.topic_id, { visible: false });
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["visible"]).to eq(false)
        expect(topic_with_category.reload.visible).to eq(false)
        expect(topic_with_category.visibility_reason_id).to eq(
          Topic.visibility_reasons[:manually_unlisted],
        )
      end

      it "can relist a topic" do
        topic_with_category.update!(visible: false)
        tool.update!(script: <<~JS)
            function invoke(params) {
              return discourse.editTopic(params.topic_id, { visible: true });
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["visible"]).to eq(true)
        expect(topic_with_category.reload.visible).to eq(true)
        expect(topic_with_category.visibility_reason_id).to eq(
          Topic.visibility_reasons[:manually_relisted],
        )
      end

      it "throws error for non-existent topic" do
        tool.update!(script: <<~JS)
            function invoke(params) {
              try {
                return discourse.editTopic(999999, { tags: ['tag1'] });
              } catch(e) {
                return { thrown: true, message: e.message };
              }
            }
          JS
        runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
        result = runner.invoke
        expect(result["thrown"]).to eq(true)
        expect(result["message"]).to include("not found")
      end

      it "can edit multiple topic properties at once" do
        new_category = Fabricate(:category, slug: "multi-edit")
        tool.update!(script: <<~JS)
            function invoke(params) {
              return discourse.editTopic(params.topic_id, {
                category: "multi-edit",
                tags: ['tag1', 'tag2'],
                visible: false
              });
            }
          JS
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(result["topic"]["category_id"]).to eq(new_category.id)
        expect(result["topic"]["tags"]).to contain_exactly("tag1", "tag2")
        expect(result["topic"]["visible"]).to eq(false)
        topic_with_category.reload
        expect(topic_with_category.category_id).to eq(new_category.id)
        expect(topic_with_category.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
        expect(topic_with_category.visible).to eq(false)
      end

      it "setTags alias works for backwards compatibility" do
        tool.update!(
          script:
            "function invoke(params) { return discourse.setTags(params.topic_id, ['tag1', 'tag2']); }",
        )
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_with_category.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(topic_with_category.reload.tags.pluck(:name)).to contain_exactly("tag1", "tag2")
      end
    end

    describe "editPost" do
      it "can edit a post" do
        edit_post = Fabricate(:post)
        tool.update!(
          script:
            "function invoke(params) { return discourse.editPost(params.post_id, 'new raw content', { edit_reason: 'AI edit' }); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: edit_post.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(edit_post.reload.raw).to eq("new raw content")
        expect(edit_post.edit_reason).to eq("AI edit")
        expect(edit_post.last_editor_id).to eq(bot_user.id)
      end

      it "can edit a post as a specific user" do
        other_user = Fabricate(:user, admin: true)
        edit_post = Fabricate(:post)
        tool.update!(
          script:
            "function invoke(params) { return discourse.editPost(params.post_id, 'new raw content', { username: '#{other_user.username}' }); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: edit_post.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["success"]).to eq(true)
        expect(edit_post.reload.last_editor_id).to eq(other_user.id)
      end

      it "denies editing a post when the user lacks permission" do
        post_author = Fabricate(:user)
        unprivileged_user = Fabricate(:user)
        edit_post = Fabricate(:post, user: post_author)
        original_raw = edit_post.raw
        tool.update!(
          script:
            "function invoke(params) { return discourse.editPost(params.post_id, 'hacked content', { username: '#{unprivileged_user.username}' }); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: edit_post.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        expect { runner.invoke }.to raise_error(/Permission denied/)
        expect(edit_post.reload.raw).to eq(original_raw)
      end
    end

    describe "guardian permission checks" do
      fab!(:private_category) do
        Fabricate(:category).tap do |c|
          c.set_permissions(staff: :full)
          c.save!
        end
      end
      fab!(:private_topic) { Fabricate(:topic, category: private_category) }

      def run_tool(script, parameters)
        tool.update!(script: script)
        described_class.new(parameters: parameters, llm: llm, bot_user: bot_user, tool: tool).invoke
      end

      it "denies regular user access to restricted topics and categories" do
        params = { username: user.username }

        expect {
          run_tool(
            "function invoke(params) { return discourse.editTopic(params.topic_id, { visible: false }, { username: params.username }); }",
            params.merge(topic_id: private_topic.id),
          )
        }.to raise_error(MiniRacer::RuntimeError, /Permission denied/)

        expect {
          run_tool(
            'function invoke(params) { return discourse.createTopic({ title: "Test title", raw: "Test body", category_id: params.category_id, username: params.username }); }',
            params.merge(category_id: private_category.id),
          )
        }.to raise_error(MiniRacer::RuntimeError, /Permission denied/)

        expect {
          run_tool(
            'function invoke(params) { return discourse.createPost({ topic_id: params.topic_id, raw: "Test reply", username: params.username }); }',
            params.merge(topic_id: private_topic.id),
          )
        }.to raise_error(MiniRacer::RuntimeError, /Permission denied/)
      end

      it "defaults to bot_user when no username is provided" do
        new_category = Fabricate(:category)
        result =
          run_tool(
            'function invoke(params) { return discourse.createTopic({ title: "Bot topic title here", raw: "Bot topic body content", category_id: params.category_id }); }',
            { category_id: new_category.id },
          )
        expect(result["success"]).to eq(true)
        expect(Topic.find(result["topic_id"]).user_id).to eq(bot_user.id)

        result =
          run_tool(
            'function invoke(params) { return discourse.createPost({ topic_id: params.topic_id, raw: "Bot reply content" }); }',
            { topic_id: topic.id },
          )
        expect(result["success"]).to eq(true)
        expect(Post.find(result["post_id"]).user_id).to eq(bot_user.id)

        topic_for_visibility = Fabricate(:topic, category: category)
        result =
          run_tool(
            "function invoke(params) { return discourse.editTopic(params.topic_id, { visible: false }); }",
            { topic_id: topic_for_visibility.id },
          )
        expect(result["success"]).to eq(true)
        expect(topic_for_visibility.reload.visible).to eq(false)
      end

      it "allows moderator to toggle visibility on a topic" do
        mod = Fabricate(:moderator)
        topic_for_mod = Fabricate(:topic, category: category)
        result =
          run_tool(
            "function invoke(params) { return discourse.editTopic(params.topic_id, { visible: false }, { username: params.username }); }",
            { topic_id: topic_for_mod.id, username: mod.username },
          )
        expect(result["success"]).to eq(true)
        expect(topic_for_mod.reload.visible).to eq(false)
      end

      it "allows user to createTopic in a permitted category" do
        result =
          run_tool(
            'function invoke(params) { return discourse.createTopic({ title: "A valid topic title here", raw: "Some body content for the topic", category_id: params.category_id, username: params.username }); }',
            { category_id: category.id, username: user.username },
          )
        expect(result["success"]).to eq(true)
        expect(result["topic_id"]).to be_present
      end

      it "allows user to createPost in a permitted topic" do
        result =
          run_tool(
            'function invoke(params) { return discourse.createPost({ topic_id: params.topic_id, raw: "A reply to the topic", username: params.username }); }',
            { topic_id: topic.id, username: user.username },
          )
        expect(result["success"]).to eq(true)
        expect(result["post_id"]).to be_present
      end

      it "returns error when user cannot move topic to category" do
        regular_user = Fabricate(:user)
        new_category = Fabricate(:category)
        new_category.set_permissions(staff: :full)
        new_category.save!
        tool.update!(script: <<~JS)
            function invoke(params) {
              try {
                return discourse.editTopic(params.topic_id, { category: params.category_id }, { username: params.username });
              } catch(e) {
                return { error: e.message };
              }
            }
          JS
        topic_for_perms = Fabricate(:topic, category: category)
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_for_perms.id,
              category_id: new_category.id,
              username: regular_user.username,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["error"]).to include("Permission denied")
      end

      it "returns error when user cannot toggle topic visibility" do
        regular_user = Fabricate(:user)
        tool.update!(script: <<~JS)
            function invoke(params) {
              try {
                return discourse.editTopic(params.topic_id, { visible: false }, { username: params.username });
              } catch(e) {
                return { error: e.message };
              }
            }
          JS
        topic_for_visibility = Fabricate(:topic, category: category)
        runner =
          described_class.new(
            parameters: {
              topic_id: topic_for_visibility.id,
              username: regular_user.username,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result["error"]).to include("Permission denied")
      end
    end

    describe "custom fields" do
      it "can get a custom field from a post" do
        cf_post = Fabricate(:post)
        cf_post.custom_fields["test_key"] = "test_value"
        cf_post.save_custom_fields

        tool.update!(
          script:
            "function invoke(params) { return discourse.getCustomField('post', params.post_id, 'test_key'); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: cf_post.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result).to eq("test_value")
      end

      it "can set a custom field on a post" do
        cf_post = Fabricate(:post)

        tool.update!(
          script:
            "function invoke(params) { return discourse.setCustomField('post', params.post_id, 'ai_processed', 'yes'); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: cf_post.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke

        expect(result["success"]).to eq(true)
        expect(cf_post.reload.custom_fields["ai_processed"]).to eq("yes")
      end

      it "returns null for non-existent custom field" do
        cf_post = Fabricate(:post)

        tool.update!(
          script:
            "function invoke(params) { return discourse.getCustomField('post', params.post_id, 'nonexistent'); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: cf_post.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result).to be_nil
      end

      it "works with topic custom fields" do
        cf_topic = Fabricate(:topic)

        tool.update!(
          script:
            "function invoke(params) { discourse.setCustomField('topic', params.topic_id, 'processed', 'true'); return discourse.getCustomField('topic', params.topic_id, 'processed'); }",
        )
        runner =
          described_class.new(
            parameters: {
              topic_id: cf_topic.id,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke
        expect(result).to eq("true")
      end

      it "throws error for invalid type in setCustomField" do
        tool.update!(
          script:
            "function invoke(params) { return discourse.setCustomField('invalid', 1, 'key', 'val'); }",
        )
        runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Invalid type/)
      end

      it "throws error for invalid type in getCustomField" do
        tool.update!(
          script:
            "function invoke(params) { return discourse.getCustomField('invalid', 1, 'key'); }",
        )
        runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Invalid type/)
      end

      it "throws error for key too long" do
        cf_post = Fabricate(:post)
        long_key = "k" * (described_class::MAX_CUSTOM_FIELD_KEY_LENGTH + 1)

        tool.update!(
          script:
            "function invoke(params) { return discourse.setCustomField('post', params.post_id, params.key, 'val'); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: cf_post.id,
              key: long_key,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Key too long/)
      end

      it "throws error for value too long" do
        cf_post = Fabricate(:post)
        long_value = "v" * (described_class::MAX_CUSTOM_FIELD_VALUE_LENGTH + 1)

        tool.update!(
          script:
            "function invoke(params) { return discourse.setCustomField('post', params.post_id, 'key', params.value); }",
        )
        runner =
          described_class.new(
            parameters: {
              post_id: cf_post.id,
              value: long_value,
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        expect { runner.invoke }.to raise_error(MiniRacer::RuntimeError, /Value too long/)
      end
    end
  end
end
