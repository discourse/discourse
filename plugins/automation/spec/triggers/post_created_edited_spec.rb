# frozen_string_literal: true

describe "PostCreatedEdited" do
  before { SiteSetting.discourse_automation_enabled = true }

  let(:basic_topic_params) do
    { title: "hello world topic", raw: "my name is fred", archetype: Archetype.default }
  end
  let(:parent_category) { Fabricate(:category_with_definition) }
  let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: parent_category.id) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:automation) { Fabricate(:automation, trigger: "post_created_edited") }

  context "when filtering on first post only" do
    before do
      automation.upsert_field!("first_post_only", "boolean", { value: true }, target: "trigger")
    end

    it "fires on first post, but not on second" do
      post = create_post(title: "hello world topic", raw: "my name is fred")
      topic = post.topic

      list =
        capture_contexts do
          PostCreator.create!(user, raw: "this is a test reply", topic_id: topic.id)
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("post_created_edited")
      expect(list[0]["action"].to_s).to eq("create")

      list =
        capture_contexts do
          PostCreator.create!(user, raw: "this is another test reply", topic_id: topic.id)
        end
      expect(list.length).to eq(0)
    end
  end

  context "when filtering on first topic only" do
    before do
      automation.upsert_field!("first_topic_only", "boolean", { value: true }, target: "trigger")
    end

    it "does not fire if it is not a topic" do
      post = create_post(title: "hello world topic", raw: "my name is fred")
      topic = post.topic

      list =
        capture_contexts do
          PostCreator.create!(user, raw: "this is a test reply", topic_id: topic.id)
        end

      expect(list.length).to eq(0)
    end

    it "fires if it is a first topic (and not on second)" do
      list =
        capture_contexts do
          PostCreator.create!(user, raw: "this is a test reply", title: "hello there mister")
        end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("post_created_edited")
      expect(list[0]["action"].to_s).to eq("create")

      list =
        capture_contexts do
          PostCreator.create!(user, raw: "this is a test reply 2", title: "hello there mister 2")
        end

      expect(list.length).to eq(0)
    end
  end

  context "when editing/creating a post" do
    it "fires the trigger" do
      post = nil

      list = capture_contexts { post = PostCreator.create(user, basic_topic_params) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("post_created_edited")
      expect(list[0]["action"].to_s).to eq("create")

      list = capture_contexts { post.revise(post.user, raw: "this is another cool topic") }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("post_created_edited")
      expect(list[0]["action"].to_s).to eq("edit")
    end

    context "when trust_levels are restricted" do
      before do
        automation.upsert_field!(
          "valid_trust_levels",
          "trust-levels",
          { value: [0] },
          target: "trigger",
        )
      end

      context "when trust level is allowed" do
        it "fires the trigger" do
          list =
            capture_contexts do
              user.trust_level = TrustLevel[0]
              PostCreator.create(user, basic_topic_params)
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end
      end

      context "when trust level is not allowed" do
        it "doesn’t fire the trigger" do
          list =
            capture_contexts do
              user.trust_level = TrustLevel[1]
              PostCreator.create(user, basic_topic_params)
            end

          expect(list).to be_blank
        end
      end
    end

    context "when group is restricted" do
      fab!(:target_group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]) }

      before do
        automation.upsert_field!(
          "restricted_group",
          "group",
          { value: target_group.id },
          target: "trigger",
        )
      end

      it "fires the trigger" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              basic_topic_params.merge(
                target_group_names: [target_group.name],
                archetype: Archetype.private_message,
              ),
            )
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      context "when the topic is not a PM" do
        it "doesn’t fire the trigger" do
          list =
            capture_contexts do
              user.groups << target_group
              PostCreator.create(user, basic_topic_params)
            end

          expect(list).to be_blank
        end
      end

      context "when members of the group are ignored" do
        before do
          automation.upsert_field!(
            "ignore_group_members",
            "boolean",
            { value: true },
            target: "trigger",
          )
        end

        it "doesn’t fire the trigger" do
          list =
            capture_contexts do
              user.groups << target_group
              PostCreator.create(
                user,
                basic_topic_params.merge(
                  target_group_names: [target_group.name],
                  archetype: Archetype.private_message,
                ),
              )
            end

          expect(list).to be_blank
        end
      end

      context "when a different group is used" do
        it "does not fire the trigger" do
          list =
            capture_contexts do
              PostCreator.create(
                user,
                basic_topic_params.merge(
                  target_group_names: [Fabricate(:group).name],
                  archetype: Archetype.private_message,
                ),
              )
            end

          expect(list).to be_blank
        end
      end
    end

    context "when the post is being created from an incoming email" do
      let(:reply_key) { "4f97315cc828096c9cb34c6f1a0d6fe8" }
      fab!(:user) { Fabricate(:user, email: "discourse@bar.com", refresh_auto_groups: true) }
      fab!(:topic) { create_topic(user: user) }
      fab!(:post) { create_post(topic: topic) }

      let!(:post_reply_key) do
        Fabricate(:post_reply_key, reply_key: reply_key, user: user, post: post)
      end

      before do
        SiteSetting.email_in = true
        SiteSetting.reply_by_email_address = "reply+%{reply_key}@bar.com"
        SiteSetting.alternative_reply_by_email_addresses = "alt+%{reply_key}@bar.com"
      end

      it "fires the trigger" do
        list = capture_contexts { Email::Receiver.new(email("html_reply")).process! }

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
        expect(list[0]["action"].to_s).to eq("create")
      end

      context "when the incoming email is automated" do
        before { SiteSetting.block_auto_generated_emails = false }

        it "fires the trigger" do
          list =
            capture_contexts { Email::Receiver.new(email("auto_generated_unblocked")).process! }

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end

        context "when ignore_automated is true" do
          before do
            automation.upsert_field!(
              "ignore_automated",
              "boolean",
              { value: true },
              target: "trigger",
            )
          end

          it "doesn't fire the trigger" do
            list =
              capture_contexts { Email::Receiver.new(email("auto_generated_unblocked")).process! }

            expect(list).to be_blank
          end
        end
      end
    end

    context "when category is restricted" do
      before do
        automation.upsert_field!(
          "restricted_category",
          "category",
          { value: Category.first.id },
          target: "trigger",
        )
      end

      context "when category is allowed" do
        it "fires the trigger" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: Category.first.id }))
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end
      end

      context "when restricted to a subcategory" do
        before do
          automation.upsert_field!(
            "restricted_category",
            "category",
            { value: subcategory.id },
            target: "trigger",
          )
        end

        it "fires the trigger" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: subcategory.id }))
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end

        it "does not fire the trigger for the parent" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: parent_category.id }))
            end

          expect(list.length).to eq(0)
        end
      end

      context "when restricted to a parent category" do
        before do
          automation.upsert_field!(
            "restricted_category",
            "category",
            { value: parent_category.id },
            target: "trigger",
          )
        end

        it "fires the trigger for a subcategory" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: subcategory.id }))
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end

        it "fires the trigger for the parent" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: parent_category.id }))
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end
      end

      context "when category is not allowed" do
        fab!(:category)

        it "doesn’t fire the trigger" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: category.id }))
            end

          expect(list).to be_blank
        end
      end
    end

    context "when action_type is set to create" do
      before do
        automation.upsert_field!("action_type", "choices", { value: "created" }, target: "trigger")
      end

      it "fires the trigger only for create" do
        post = nil

        list = capture_contexts { post = PostCreator.create(user, basic_topic_params) }

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
        expect(list[0]["action"].to_s).to eq("create")

        list = capture_contexts { post.revise(post.user, raw: "this is another cool topic") }

        expect(list.length).to eq(0)
      end
    end

    context "when action_type is set to edit" do
      before do
        automation.upsert_field!("action_type", "choices", { value: "edited" }, target: "trigger")
      end

      it "fires the trigger only for edit" do
        post = nil

        list = capture_contexts { post = PostCreator.create(user, basic_topic_params) }

        expect(list.length).to eq(0)

        list = capture_contexts { post.revise(post.user, raw: "this is another cool topic") }

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
        expect(list[0]["action"].to_s).to eq("edit")
      end
    end
  end
end
