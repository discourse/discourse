# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicPin::V1 do
  fab!(:topic)
  fab!(:user)
  fab!(:trust_level_4)

  let(:item) { { "json" => {} } }

  describe "#execute" do
    context "with the pin type" do
      context "with the add operation" do
        it "pins the topic in its category" do
          config = { "operation" => "add", "topic_id" => topic.id.to_s }

          result = execute_node(configuration: config, item: item)

          expect(result["pinned"]).to eq(true)
          expect(result["pinned_globally"]).to eq(false)
          expect(result).to match_node_output_schema(described_class, configuration: config)

          topic.reload
          expect(topic.pinned_at).to be_present
          expect(topic.pinned_globally).to eq(false)
        end

        it "pins the topic globally" do
          config = { "operation" => "add", "topic_id" => topic.id.to_s, "pinned_globally" => true }

          result = execute_node(configuration: config, item: item)

          expect(result["pinned"]).to eq(true)
          expect(result["pinned_globally"]).to eq(true)

          topic.reload
          expect(topic.pinned_at).to be_present
          expect(topic.pinned_globally).to eq(true)
        end

        it "sets pinned_until" do
          pinned_until = 3.days.from_now.utc.strftime("%Y-%m-%d %H:%M%z")
          config = {
            "operation" => "add",
            "topic_id" => topic.id.to_s,
            "pinned_until" => pinned_until,
          }

          result = execute_node(configuration: config, item: item)

          expect(result["pinned_until"]).to eq(Time.parse(pinned_until).utc.iso8601)
          expect(topic.reload.pinned_until).to eq_time(Time.parse(pinned_until))
        end

        it "pins indefinitely when pinned_until is blank" do
          config = { "operation" => "add", "topic_id" => topic.id.to_s, "pinned_until" => "" }

          result = execute_node(configuration: config, item: item)

          expect(result["pinned"]).to eq(true)
          expect(result["pinned_until"]).to be_nil
          expect(topic.reload.pinned_until).to be_nil
        end

        context "when pinned_until carries no timezone offset" do
          fab!(:workflow) do
            Fabricate(:discourse_workflows_workflow, settings: { "timezone" => "America/New_York" })
          end

          it "anchors the value to the workflow timezone" do
            config = {
              "operation" => "add",
              "topic_id" => topic.id.to_s,
              "pinned_until" => "2026-08-01 12:00",
            }

            execute_node(configuration: config, item: item, workflow: workflow)

            # noon in New York on that date is 16:00 UTC, regardless of the server clock
            expect(topic.reload.pinned_until.utc).to eq_time(Time.utc(2026, 8, 1, 16, 0))
          end

          it "prefers the node timezone over the workflow timezone" do
            config = {
              "operation" => "add",
              "topic_id" => topic.id.to_s,
              "pinned_until" => "2026-08-01 12:00",
              "timezone" => "Europe/Paris",
            }

            execute_node(configuration: config, item: item, workflow: workflow)

            expect(topic.reload.pinned_until.utc).to eq_time(Time.utc(2026, 8, 1, 10, 0))
          end

          it "applies the node timezone to bannered_until too" do
            config = {
              "operation" => "add",
              "pin_type" => "banner",
              "topic_id" => topic.id.to_s,
              "bannered_until" => "2026-08-01 12:00",
              "timezone" => "Europe/Paris",
            }

            execute_node(configuration: config, item: item, workflow: workflow)

            expect(topic.reload.bannered_until.utc).to eq_time(Time.utc(2026, 8, 1, 10, 0))
          end

          it "raises a readable error for an unknown node timezone" do
            config = {
              "operation" => "add",
              "topic_id" => topic.id.to_s,
              "pinned_until" => "2026-08-01 12:00",
              "timezone" => "Mars/Olympus_Mons",
            }

            expect {
              execute_node(configuration: config, item: item, workflow: workflow)
            }.to raise_error(DiscourseWorkflows::NodeError, %r{Invalid timezone: Mars/Olympus_Mons})
          end

          it "keeps an explicit offset instead of reinterpreting it" do
            config = {
              "operation" => "add",
              "topic_id" => topic.id.to_s,
              "pinned_until" => "2026-08-01 12:00+02:00",
            }

            execute_node(configuration: config, item: item, workflow: workflow)

            expect(topic.reload.pinned_until.utc).to eq_time(Time.utc(2026, 8, 1, 10, 0))
          end

          it "raises a readable error for an unparseable value" do
            config = { "operation" => "add", "topic_id" => topic.id.to_s, "pinned_until" => "soon" }

            expect {
              execute_node(configuration: config, item: item, workflow: workflow)
            }.to raise_error(
              DiscourseWorkflows::NodeError,
              "'pinned_until' is not a valid date and time: 'soon'.",
            )
          end

          it "raises a readable error for an out-of-range date" do
            config = {
              "operation" => "add",
              "topic_id" => topic.id.to_s,
              "pinned_until" => "2026-13-45",
            }

            expect {
              execute_node(configuration: config, item: item, workflow: workflow)
            }.to raise_error(
              DiscourseWorkflows::NodeError,
              "'pinned_until' is not a valid date and time: '2026-13-45'.",
            )
          end
        end

        it "adds a small action post" do
          config = { "operation" => "add", "topic_id" => topic.id.to_s }

          expect { execute_node(configuration: config, item: item) }.to change {
            topic.posts.where(action_code: "pinned.enabled").count
          }.by(1)
        end
      end

      context "with the remove operation" do
        it "unpins a topic pinned in its category" do
          topic.update_pinned(true)

          config = { "operation" => "remove", "topic_id" => topic.id.to_s }

          result = execute_node(configuration: config, item: item)

          expect(result["pinned"]).to eq(false)
          expect(topic.reload.pinned_at).to be_nil
        end

        it "clears pinned_globally when unpinning a globally pinned topic" do
          topic.update_pinned(true, true)

          config = { "operation" => "remove", "topic_id" => topic.id.to_s }

          result = execute_node(configuration: config, item: item)

          expect(result["pinned"]).to eq(false)
          expect(result["pinned_globally"]).to eq(false)

          topic.reload
          expect(topic.pinned_at).to be_nil
          expect(topic.pinned_globally).to eq(false)
        end

        it "does nothing when the topic is not pinned" do
          config = { "operation" => "remove", "topic_id" => topic.id.to_s }

          expect { execute_node(configuration: config, item: item) }.not_to change {
            topic.posts.count
          }
        end
      end
    end

    context "with the banner pin type" do
      it "makes the topic a banner" do
        config = { "operation" => "add", "pin_type" => "banner", "topic_id" => topic.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["banner"]).to eq(true)
        expect(result).to match_node_output_schema(described_class, configuration: config)
        expect(topic.reload.archetype).to eq(Archetype.banner)
      end

      it "replaces an existing banner topic" do
        previous_banner = Fabricate(:topic, archetype: Archetype.banner)

        config = { "operation" => "add", "pin_type" => "banner", "topic_id" => topic.id.to_s }

        execute_node(configuration: config, item: item)

        expect(topic.reload.archetype).to eq(Archetype.banner)
        expect(previous_banner.reload.archetype).to eq(Archetype.default)
      end

      it "sets bannered_until" do
        bannered_until = 3.days.from_now.utc.strftime("%Y-%m-%d %H:%M%z")
        config = {
          "operation" => "add",
          "pin_type" => "banner",
          "topic_id" => topic.id.to_s,
          "bannered_until" => bannered_until,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["bannered_until"]).to eq(Time.parse(bannered_until).utc.iso8601)
        expect(topic.reload.bannered_until).to eq_time(Time.parse(bannered_until))
      end

      it "banners indefinitely when bannered_until is blank" do
        config = {
          "operation" => "add",
          "pin_type" => "banner",
          "topic_id" => topic.id.to_s,
          "bannered_until" => "",
        }

        result = execute_node(configuration: config, item: item)

        expect(result["banner"]).to eq(true)
        expect(result["bannered_until"]).to be_nil
      end

      it "removes the banner" do
        topic.make_banner!(Discourse.system_user)

        config = { "operation" => "remove", "pin_type" => "banner", "topic_id" => topic.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["banner"]).to eq(false)
        expect(topic.reload.archetype).to eq(Archetype.default)
      end

      it "does nothing when the topic is not a banner" do
        config = { "operation" => "remove", "pin_type" => "banner", "topic_id" => topic.id.to_s }

        expect { execute_node(configuration: config, item: item) }.not_to change {
          topic.posts.count
        }
      end
    end

    context "with permissions" do
      it "raises when the actor cannot pin the topic" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "actor_username" => user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /'#{user.username}' cannot pin or unpin topic #{topic.id}/,
        )
        expect(topic.reload.pinned_at).to be_nil
      end

      it "raises when the actor cannot pin the topic globally" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "pinned_globally" => true,
          "actor_username" => user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /cannot pin topic #{topic.id} globally/,
        )
        expect(topic.reload.pinned_globally).to eq(false)
      end

      it "allows a TL4 actor to pin globally" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "pinned_globally" => true,
          "actor_username" => trust_level_4.username,
        }

        execute_node(configuration: config, item: item)

        expect(topic.reload.pinned_globally).to eq(true)
      end

      it "raises when a non-staff actor banners the topic" do
        config = {
          "operation" => "add",
          "pin_type" => "banner",
          "topic_id" => topic.id.to_s,
          "actor_username" => trust_level_4.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /can only be managed by staff/,
        )
        expect(topic.reload.archetype).to eq(Archetype.default)
      end

      it "reports the personal message reason when bannering a PM as staff" do
        pm = Fabricate(:private_message_topic)

        config = { "operation" => "add", "pin_type" => "banner", "topic_id" => pm.id.to_s }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          "Personal messages cannot be made into banner topics.",
        )
      end

      it "reports the restricted category reason when bannering as staff" do
        private_category = Fabricate(:private_category, group: Fabricate(:group))
        restricted = Fabricate(:topic, category: private_category)

        config = { "operation" => "add", "pin_type" => "banner", "topic_id" => restricted.id.to_s }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          "Topics in a restricted category cannot be made into banner topics.",
        )
      end

      it "raises when pinning as the anonymous actor" do
        config = {
          "operation" => "add",
          "topic_id" => topic.id.to_s,
          "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          DiscourseWorkflows::NodeError,
          /'anonymous' cannot pin or unpin topic #{topic.id}/,
        )
      end
    end

    it "raises when the topic does not exist" do
      config = { "operation" => "add", "topic_id" => "-1" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises on an unknown operation" do
      config = { "operation" => "toggle", "topic_id" => topic.id.to_s }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Unknown operation: toggle.",
      )
    end

    it "raises on an unknown pin type" do
      config = { "operation" => "add", "pin_type" => "sticky", "topic_id" => topic.id.to_s }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Unknown pin type: sticky.",
      )
    end
  end
end
