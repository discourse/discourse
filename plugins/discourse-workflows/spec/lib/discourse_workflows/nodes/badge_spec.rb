# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Badge::V1 do
  fab!(:user)
  fab!(:badge)

  describe ".upgrade" do
    let(:badge_parameters) do
      { "username" => "={{ $json.user.username }}", "badge_id" => 12, "actor_username" => "system" }
    end

    it "moves granting to Grant badge, warning about the output" do
      expect(described_class.upgrade(badge_parameters.merge("operation" => "grant"))).to eq(
        type: "action:grant_badge",
        parameters: badge_parameters,
        notes: ["discourse_workflows.node_upgrades.badge_output"],
      )
    end

    it "keeps the reason when granting" do
      expect(
        described_class.upgrade(badge_parameters.merge("reason" => "=post:{{ $json.post.id }}")),
      ).to include(parameters: badge_parameters.merge("reason" => "=post:{{ $json.post.id }}"))
    end

    it "treats a node without an operation as granting" do
      expect(described_class.upgrade(badge_parameters)).to include(type: "action:grant_badge")
    end

    it "moves revoking to Revoke badge, warning that every grant is revoked" do
      expect(described_class.upgrade(badge_parameters.merge("operation" => "revoke"))).to eq(
        type: "action:revoke_badge",
        parameters: badge_parameters,
        notes: %w[
          discourse_workflows.node_upgrades.badge_output
          discourse_workflows.node_upgrades.badge_revoke_all_grants
        ],
      )
    end

    it "leaves a node whose operation is an expression to be replaced by hand" do
      expect(described_class.upgrade("operation" => "={{ $json.operation }}")).to be_nil
    end

    it "upgrades a saved revoke node with translated notes" do
      node = {
        "id" => "node-1",
        "type" => "action:badge",
        "typeVersion" => "1.0",
        "name" => "Revoke",
        "parameters" => badge_parameters.merge("operation" => "revoke"),
      }

      result = DiscourseWorkflows::NodeUpgrader.call([node])

      expect(result.nodes.sole).to include(
        "type" => "action:revoke_badge",
        "typeVersion" => "1.0",
        "parameters" => badge_parameters,
      )
      expect(result.upgrades.sole.notes).to eq(
        [
          I18n.t("discourse_workflows.node_upgrades.badge_output"),
          I18n.t("discourse_workflows.node_upgrades.badge_revoke_all_grants"),
        ],
      )
    end
  end

  describe ".load_options_context" do
    fab!(:badge_2) { Fabricate(:badge, name: "A badge") }

    subject(:options) do
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "badges",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    let(:filter) { nil }

    it "returns enabled badges for the chooser" do
      expect(options).to include(
        { id: badge_2.id, name: badge_2.name, hide_reason: false },
        { id: badge.id, name: badge.name, hide_reason: false },
      )
    end

    it "excludes disabled badges" do
      disabled_badge = Fabricate(:badge, name: "Disabled Badge", enabled: false)
      expect(options.pluck(:id)).not_to include(disabled_badge.id)
    end

    it "marks built-in badges whose post visibility is locked off" do
      badge_with_visible_posts = Fabricate(:badge, system: true, show_posts: true)

      expect(options).to include(
        a_hash_including(id: Badge::Anniversary, hide_reason: true),
        a_hash_including(id: badge_with_visible_posts.id, hide_reason: false),
      )
    end

    context "with a filter term" do
      let(:filter) { "A badge" }

      it "filters badges" do
        expect(options).to contain_exactly(
          { id: badge_2.id, name: badge_2.name, hide_reason: false },
        )
      end
    end
  end

  describe "#execute" do
    fab!(:admin)

    let(:item) { { "json" => {} } }

    context "with grant operation" do
      it "grants the badge to the user", :aggregate_failures do
        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["user_id"]).to eq(user.id)
        expect(result["username"]).to eq(user.username)
        expect(result["badge_id"]).to eq(badge.id)
        expect(result["badge_name"]).to eq(badge.name)
        expect(result["changed"]).to be(true)
        expect(UserBadge.exists?(user: user, badge: badge)).to be(true)
        expect(result).to match_node_output_schema(described_class)
      end

      it "does not duplicate a non-multiple-grant badge" do
        BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = nil
        expect { result = execute_node(configuration: config, item: item) }.not_to change {
          UserBadge.where(user: user, badge: badge).count
        }
        expect(result["changed"]).to be(false)
      end

      context "with a reason" do
        let(:grant_config) do
          { "operation" => "grant", "username" => user.username, "badge_id" => badge.id.to_s }
        end

        def granted_post_id(badge_id: badge.id)
          UserBadge.find_by!(user:, badge_id:).post_id
        end

        it "associates the grant with the post from a URL expression" do
          post = Fabricate(:post)

          execute_node(
            configuration: grant_config.merge("reason" => "={{ $json.post_url }}"),
            item: {
              "json" => {
                "post_url" => post.full_url,
              },
            },
          )

          expect(granted_post_id).to eq(post.id)
        end

        it "rejects an external URL" do
          expect {
            execute_node(
              configuration: grant_config.merge("reason" => "https://example.com/t/42"),
              item:,
            )
          }.to raise_error(
            DiscourseWorkflows::NodeError,
            I18n.t("invalid_grant_badge_reason_link"),
          ).and not_change { UserBadge.count }
        end

        it "associates the grant with the topic's first post for a prefixed topic ID" do
          post = Fabricate(:post)

          execute_node(
            configuration: grant_config.merge("reason" => "topic:#{post.topic_id}"),
            item:,
          )

          expect(granted_post_id).to eq(post.id)
        end

        it "associates the grant with the post for a prefixed post ID expression" do
          reply = Fabricate(:post, topic: Fabricate(:post).topic)

          execute_node(
            configuration: grant_config.merge("reason" => "=post:{{ $json.post_id }}"),
            item: {
              "json" => {
                "post_id" => reply.id,
              },
            },
          )

          expect(granted_post_id).to eq(reply.id)
        end

        it "requires a prefix for a bare ID" do
          post = Fabricate(:post)

          expect {
            execute_node(
              configuration: grant_config.merge("reason" => "={{ $json.topic_id }}"),
              item: {
                "json" => {
                  "topic_id" => post.topic_id,
                },
              },
            )
          }.to raise_error(
            DiscourseWorkflows::NodeError,
            I18n.t("discourse_workflows.errors.badge.reason_id_requires_prefix", id: post.topic_id),
          ).and not_change { UserBadge.count }
        end

        it "reports missing post and topic references as node errors" do
          %w[post:0 topic:0].each do |reference|
            expect {
              execute_node(configuration: grant_config.merge("reason" => reference), item:)
            }.to raise_error(
              DiscourseWorkflows::NodeError,
              I18n.t("discourse_workflows.errors.badge.reason_id_not_found", reference:),
            ).and not_change { UserBadge.count }
          end
        end

        it "ignores the reason when the badge's post visibility is locked off" do
          post = Fabricate(:post)

          execute_node(
            configuration:
              grant_config.merge("badge_id" => Badge::Anniversary, "reason" => "post:#{post.id}"),
            item:,
          )

          expect(granted_post_id(badge_id: Badge::Anniversary)).to be_nil
        end
      end

      it "reports no change when the badge is disabled" do
        badge.update!(enabled: false)

        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["changed"]).to be(false)
      end

      it "raises when granting as the anonymous actor" do
        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
          "actor_username" => DiscourseWorkflows::AnonymousActor::USERNAME,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        ).and not_change { UserBadge.count }
      end
    end

    context "with revoke operation" do
      it "revokes the badge from the user" do
        BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

        config = {
          "operation" => "revoke",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = execute_node(configuration: config, item: item)

        expect(UserBadge.exists?(user: user, badge: badge)).to be(false)
        expect(result["changed"]).to be(true)
      end

      it "is idempotent when user does not have the badge" do
        config = {
          "operation" => "revoke",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = nil
        expect { result = execute_node(configuration: config, item: item) }.not_to change {
          UserBadge.where(user: user, badge: badge).count
        }

        expect(result).to include(
          "user_id" => user.id,
          "username" => user.username,
          "badge_id" => badge.id,
          "badge_name" => badge.name,
          "changed" => false,
        )
      end
    end

    it "raises when user does not exist" do
      config = {
        "operation" => "grant",
        "username" => "nonexistent_user",
        "badge_id" => badge.id.to_s,
      }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        node_error_message(:not_found, scope: :actor, username: "nonexistent_user"),
      )
    end

    it "raises when badge does not exist" do
      config = { "operation" => "grant", "username" => user.username, "badge_id" => "-1" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "uses actor_username when granting" do
      config = {
        "operation" => "grant",
        "username" => user.username,
        "badge_id" => badge.id.to_s,
        "actor_username" => admin.username,
      }

      execute_node(configuration: config, item: item)

      expect(UserBadge.find_by(user: user, badge: badge).granted_by_id).to eq(admin.id)
    end

    it "uses actor_username when revoking" do
      BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

      config = {
        "operation" => "revoke",
        "username" => user.username,
        "badge_id" => badge.id.to_s,
        "actor_username" => admin.username,
      }

      execute_node(configuration: config, item: item)

      expect(UserBadge.exists?(user: user, badge: badge)).to be(false)
    end

    it "defaults to system user when actor_username is not set" do
      config = { "operation" => "grant", "username" => user.username, "badge_id" => badge.id.to_s }

      execute_node(configuration: config, item: item)

      expect(UserBadge.find_by(user: user, badge: badge).granted_by_id).to eq(
        Discourse.system_user.id,
      )
    end
  end
end
