# frozen_string_literal: true

describe "PostCreatedEdited" do
  before { SiteSetting.discourse_automation_enabled = true }

  let(:basic_topic_params) do
    { title: "hello world topic", raw: "my name is fred", archetype: Archetype.default }
  end
  let(:parent_category) { Fabricate(:category_with_definition) }
  let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: parent_category.id) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
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

  context "when skipping posts created via email" do
    before do
      automation.upsert_field!("skip_via_email", "boolean", { value: true }, target: "trigger")
    end

    let(:parent_post) { create_post(title: "hello world topic", raw: "my name is fred") }

    it "fires if the post didn't come via email" do
      topic = parent_post.topic

      list =
        capture_contexts do
          PostCreator.create!(user, raw: "this is a test reply", topic_id: topic.id)
        end

      expect(list.length).to eq(1)
    end

    it "skips the trigger if the post came via email" do
      topic = parent_post.topic

      list =
        capture_contexts do
          PostCreator.create!(
            user,
            raw: "this is a test reply",
            topic_id: topic.id,
            via_email: true,
          )
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

    context "when user group is restricted" do
      fab!(:group)

      before do
        automation.upsert_field!(
          "restricted_groups",
          "groups",
          { value: [group.id] },
          target: "trigger",
        )
      end

      context "when user is member of the group" do
        before { group.add(user) }

        it "fires the trigger" do
          list = capture_contexts { PostCreator.create(user, basic_topic_params) }

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end
      end

      context "when user is not member of the group" do
        it "doesn’t fire the trigger" do
          list = capture_contexts { PostCreator.create(user, basic_topic_params) }

          expect(list).to be_blank
        end
      end
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
      fab!(:another_group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]) }

      before do
        automation.upsert_field!(
          "restricted_inbox_groups",
          "groups",
          { value: [target_group.id, another_group.id] },
          target: "trigger",
        )
      end

      context "when PM is not sent to the group" do
        it "doesnt fire the trigger" do
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

          expect(list.length).to eq(0)
        end
      end

      context "when PM is sent to the group" do
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

    context "with original_post_only" do
      before do
        automation.upsert_field!(
          "original_post_only",
          "boolean",
          { value: true },
          target: "trigger",
        )
      end

      it "fires the trigger only for OP" do
        list = capture_contexts { PostCreator.create(user, basic_topic_params) }

        expect(list.length).to eq(1)

        list =
          capture_contexts do
            PostCreator.create(
              user,
              basic_topic_params.merge({ topic_id: list[0]["post"].topic_id }),
            )
          end

        expect(list.length).to eq(0)
      end
    end

    context "when tags is restricted" do
      fab!(:tag_1) { Fabricate(:tag) }

      before do
        automation.upsert_field!(
          "restricted_tags",
          "tags",
          { value: [tag_1.name] },
          target: "trigger",
        )
      end

      context "when tag is allowed" do
        it "fires the trigger" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ tags: [tag_1.name] }))
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end
      end

      context "when tag is not allowed" do
        it "fires the trigger" do
          list = capture_contexts { PostCreator.create(user, basic_topic_params.merge()) }

          expect(list.length).to eq(0)
        end
      end
    end

    context "when using restricted_categories with deeply nested categories" do
      before_all { SiteSetting.max_category_nesting = 3 }

      fab!(:top_category) { Fabricate(:category) }
      fab!(:mid_category) { Fabricate(:category, parent_category_id: top_category.id) }
      fab!(:bottom_category) { Fabricate(:category, parent_category_id: mid_category.id) }
      fab!(:another_category) { Fabricate(:category) }

      before do
        automation.upsert_field!(
          "restricted_categories",
          "categories",
          { value: [top_category.id] },
          target: "trigger",
        )
      end

      it "fires the trigger for posts in any grand child category" do
        list =
          capture_contexts do
            PostCreator.create(user, basic_topic_params.merge({ category: bottom_category.id }))
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      it "will not fire on unrelated categories" do
        list =
          capture_contexts do
            PostCreator.create(user, basic_topic_params.merge({ category: another_category.id }))
          end
        expect(list.length).to eq(0)
      end

      it "fires the trigger for posts in any child category" do
        list =
          capture_contexts do
            PostCreator.create(user, basic_topic_params.merge({ category: mid_category.id }))
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      context "when exclude_subcategories is enabled" do
        before do
          automation.upsert_field!(
            "exclude_subcategories",
            "boolean",
            { value: true },
            target: "trigger",
          )
        end

        it "does not fire for children" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: bottom_category.id }))
            end
          expect(list.length).to eq(0)
        end

        it "fires for the exact category match" do
          list =
            capture_contexts do
              PostCreator.create(user, basic_topic_params.merge({ category: top_category.id }))
            end
          expect(list.length).to eq(1)
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

    context "when only public topics are allowed" do
      before do
        automation.upsert_field!(
          "restricted_archetype",
          "choices",
          { value: "public" },
          target: "trigger",
        )
      end

      it "fires the trigger for public topics" do
        list = capture_contexts { PostCreator.create(user, basic_topic_params) }

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      it "doesn't fire the trigger for secure categories" do
        secure_category = Fabricate(:category, read_restricted: true)
        list =
          capture_contexts do
            PostCreator.create(admin, basic_topic_params.merge(category: secure_category.id))
          end

        expect(list.length).to eq(0)
      end
    end

    context "when archetype is restricted" do
      context "when only regular topics are allowed" do
        before do
          automation.upsert_field!(
            "restricted_archetype",
            "choices",
            { value: "regular" },
            target: "trigger",
          )
        end

        it "fires the trigger for regular topics" do
          list = capture_contexts { PostCreator.create(user, basic_topic_params) }

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end

        it "doesn't fire the trigger for private messages" do
          list =
            capture_contexts do
              PostCreator.create(
                user,
                basic_topic_params.merge(
                  archetype: Archetype.private_message,
                  target_usernames: [Fabricate(:user).username],
                ),
              )
            end

          expect(list.length).to eq(0)
        end
      end

      context "when only private messages are allowed" do
        before do
          automation.upsert_field!(
            "restricted_archetype",
            "choices",
            { value: "private_message" },
            target: "trigger",
          )
        end

        it "fires the trigger for private messages" do
          list =
            capture_contexts do
              PostCreator.create(
                user,
                basic_topic_params.merge(
                  archetype: Archetype.private_message,
                  target_usernames: [Fabricate(:user).username],
                ),
              )
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("post_created_edited")
        end

        it "doesn't fire the trigger for regular topics" do
          list = capture_contexts { PostCreator.create(user, basic_topic_params) }

          expect(list.length).to eq(0)
        end
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

  context "when excluded groups are defined" do
    fab!(:excluded_group) { Fabricate(:group) }

    before do
      automation.upsert_field!(
        "excluded_groups",
        "groups",
        { value: [excluded_group.id] },
        target: "trigger",
      )
    end

    context "when user is in an excluded group" do
      before { excluded_group.add(user) }

      it "doesn't fire the trigger" do
        list = capture_contexts { PostCreator.create(user, basic_topic_params) }

        expect(list).to be_blank
      end
    end

    context "when user is not in any excluded group" do
      it "fires the trigger" do
        list = capture_contexts { PostCreator.create(user, basic_topic_params) }

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end
    end
  end

  context "when filtering on post features" do
    fab!(:topic) { Fabricate(:topic, user: user) }

    context "with images filter" do
      before do
        automation.upsert_field!(
          "post_features",
          "choices",
          { value: ["with_images"] },
          target: "trigger",
        )
      end

      it "fires the trigger when post has an image" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "Look at this image: ![image](https://example.com/image.jpg)",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      it "doesn't fire the trigger when post has no image" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "This is just regular text with no images",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(0)
      end

      it "doesn't fire the trigger when post has emojis but no regular images" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw:
                "This is regular text with an emoji but no non-emoji images :face_savoring_food:",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(0)
      end

      it "doesn't fire the trigger when post has an avatar in a quote but no regular images" do
        original_post =
          PostCreator.create(user, raw: "This is regular text with no images", topic_id: topic.id)
        quote_post_text = <<~QUOTE_POST
            [quote=\"#{user.username}}, post:#{original_post.post_number}, topic:#{original_post.topic_id}\"]
              regular text
            [/quote]
            This is a regular text post with a regular text quote, no image (but an avatar image in the quote)
          QUOTE_POST
        list =
          capture_contexts { PostCreator.create(user, raw: quote_post_text, topic_id: topic.id) }

        expect(list.length).to eq(0)
      end
    end

    context "with links filter" do
      before do
        automation.upsert_field!(
          "post_features",
          "choices",
          { value: ["with_links"] },
          target: "trigger",
        )
      end

      it "fires the trigger when post has a link" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "Check out this [link](https://example.com)",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      it "doesn't fire the trigger when post has no link" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "This is just regular text with no links",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(0)
      end
    end

    context "with code filter" do
      before do
        automation.upsert_field!(
          "post_features",
          "choices",
          { value: ["with_code"] },
          target: "trigger",
        )
      end

      it "fires the trigger when post has a code block" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "```ruby\ndef hello_world\n  puts 'hello world'\nend\n```",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      it "doesn't fire the trigger when post has no code block" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "This is just regular text with no code blocks",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(0)
      end
    end

    context "with multiple features" do
      before do
        automation.upsert_field!(
          "post_features",
          "choices",
          { value: %w[with_links with_images] },
          target: "trigger",
        )
      end

      it "fires the trigger when post has all required features" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw:
                "Check this [link](https://example.com) and ![image](https://example.com/image.jpg)",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("post_created_edited")
      end

      it "doesn't fire the trigger when post is missing a required feature" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              raw: "This only has a [link](https://example.com) but no image",
              topic_id: topic.id,
            )
          end

        expect(list.length).to eq(0)
      end
    end
  end
end
