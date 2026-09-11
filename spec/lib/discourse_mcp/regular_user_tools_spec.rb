# frozen_string_literal: true

describe DiscourseMcp::Tools do
  def request_context(user)
    instance_double(DiscourseMcp::RequestContext, user:, user_id: user.id, guardian: user.guardian)
  end

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user, :user)
  fab!(:moderator)
  fab!(:admin)

  describe DiscourseMcp::Tools::Search do
    fab!(:post) { Fabricate(:post, user:, raw: "regular parity search needle") }

    before do
      SearchIndexer.enable
      SearchIndexer.index(post, force: true)
    end

    after { SearchIndexer.disable }

    it "returns the compatible topic search contract" do
      result =
        described_class.call(
          arguments: {
            "query" => "regular parity search needle",
            "max_results" => 1,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result[:results].sole).to eq(
        id: post.topic_id,
        slug: post.topic.slug,
        title: post.topic.title,
      )
      expect(result[:meta]).to eq(total: 1, has_more: false)
    end
  end

  describe DiscourseMcp::Tools::GetTopic do
    fab!(:post) { Fabricate(:post, user:) }
    fab!(:reply) { Fabricate(:post, topic: post.topic, user: other_user) }

    it "returns the compatible bounded topic contract" do
      result =
        described_class.call(
          arguments: {
            "topic_id" => post.topic_id,
            "post_limit" => 1,
            "start_post_number" => reply.post_number,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(id: post.topic_id, posts_count: 2)
      expect(result[:posts].sole).to include(id: reply.id, raw: reply.raw)
      expect(result[:meta]).to eq(start_post: reply.post_number, returned: 1, has_more: false)
    end

    it "does not expose a topic from a private category" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group:)
      private_post = Fabricate(:post, topic: Fabricate(:topic, category: private_category))

      expect do
        described_class.call(
          arguments: {
            "topic_id" => private_post.topic_id,
          },
          request_context: request_context(user),
        )
      end.to raise_error(DiscourseMcp::ToolError)

      group.add(user)
      result =
        described_class.call(
          arguments: {
            "topic_id" => private_post.topic_id,
          },
          request_context: request_context(user),
        )

      expect(result.dig(:structuredContent, :id)).to eq(private_post.topic_id)
    end
  end

  describe DiscourseMcp::Tools::ListTopics do
    it "does not expose tags hidden from the caller" do
      hidden_tag = Fabricate(:tag)
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      topic = Fabricate(:topic, user:, tags: [hidden_tag])
      Fabricate(:post, topic:, user:)

      result =
        described_class.call(
          arguments: {
            "limit" => 50,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      listed_topic = result.fetch(:topics).find { |listed| listed[:id] == topic.id }
      expect(listed_topic.fetch(:tags)).not_to include(hidden_tag.name)
    end
  end

  describe DiscourseMcp::Tools::ListCategories do
    it "lists only categories visible to the caller" do
      public_category = Fabricate(:category)
      private_category = Fabricate(:private_category, group: Fabricate(:group))

      result =
        described_class.call(arguments: {}, request_context: request_context(user)).fetch(
          :structuredContent,
        )

      category_ids = result.fetch(:categories).pluck(:id)
      expect(category_ids).to include(public_category.id)
      expect(category_ids).not_to include(private_category.id)
    end
  end

  describe DiscourseMcp::Tools::ListTags do
    it "lists only tags visible to the caller" do
      visible_tag = Fabricate(:tag)
      hidden_tag = Fabricate(:tag)
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])

      result =
        described_class.call(
          arguments: {
            "limit" => 200,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      tag_ids = result.fetch(:tags).pluck(:id)
      expect(tag_ids).to include(visible_tag.id)
      expect(tag_ids).not_to include(hidden_tag.id)
    end
  end

  describe DiscourseMcp::Resources::Topic do
    it "does not expose tags hidden from the caller" do
      hidden_tag = Fabricate(:tag)
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      topic = Fabricate(:topic, user:, tags: [hidden_tag])

      result =
        described_class.call(
          uri: "discourse://topic/#{topic.id}",
          request_context: request_context(user),
        )

      tags = JSON.parse(result.fetch(:text)).fetch("tags")
      expect(tags).not_to include(hidden_tag.name)
    end
  end

  describe DiscourseMcp::Tools::GetPost do
    fab!(:post) { Fabricate(:post, user:) }

    it "returns the compatible post contract" do
      result =
        described_class.call(
          arguments: {
            "post_id" => post.id,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(
        id: post.id,
        topic_id: post.topic_id,
        topic_slug: post.topic.slug,
        raw: post.raw,
        truncated: false,
      )
    end
  end

  describe DiscourseMcp::Tools::GetUser do
    it "returns profile fields visible to the caller" do
      user.user_profile.update!(bio_raw: "Hello")

      result =
        described_class.call(
          arguments: {
            "username" => user.username,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(
        id: user.id,
        username: user.username,
        bio: "Hello",
        admin: false,
        moderator: false,
      )
    end
  end

  describe DiscourseMcp::Tools::ListBookmarks do
    it "lists only the caller's visible bookmarks" do
      visible_bookmark = Fabricate(:bookmark, user:)
      Fabricate(:bookmark, user: other_user)
      private_post =
        Fabricate(
          :post,
          topic:
            Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group))),
        )
      hidden_bookmark = Fabricate(:bookmark, user:, bookmarkable: private_post)

      result =
        described_class.call(arguments: {}, request_context: request_context(user)).fetch(
          :structuredContent,
        )

      bookmark_ids = result.fetch(:bookmarks).pluck(:id)
      expect(bookmark_ids).to include(visible_bookmark.id)
      expect(bookmark_ids).not_to include(hidden_bookmark.id)
    end
  end

  describe DiscourseMcp::Tools::ListNotifications do
    it "lists only the caller's notifications from visible topics" do
      visible_notification = Fabricate(:notification, user:)
      Fabricate(:notification, user: other_user)
      private_topic =
        Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
      hidden_notification = Fabricate(:notification, user:, topic: private_topic)

      result =
        described_class.call(arguments: {}, request_context: request_context(user)).fetch(
          :structuredContent,
        )

      notification_ids = result.fetch(:notifications).pluck(:id)
      expect(notification_ids).to include(visible_notification.id)
      expect(notification_ids).not_to include(hidden_notification.id)
    end
  end

  describe DiscourseMcp::Tools::UpdateTopic do
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post) { Fabricate(:post, topic:, user:) }

    it "lets an author update an editable topic" do
      result =
        described_class.call(
          arguments: {
            "topic_id" => post.topic_id,
            "title" => "A much better topic title",
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(success: true, updated_fields: ["title"])
      expect(post.topic.reload.title).to eq("A much better topic title")
    end

    it "does not let another regular user update the topic" do
      expect do
        described_class.call(
          arguments: {
            "topic_id" => post.topic_id,
            "title" => "Not allowed",
          },
          request_context: request_context(other_user),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "preserves and does not expose tags hidden from the caller" do
      hidden_tag = Fabricate(:tag)
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      topic.tags << hidden_tag

      result =
        described_class.call(
          arguments: {
            "topic_id" => post.topic_id,
            "title" => "A title changed without seeing hidden tags",
            "original_tags" => [],
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result.dig(:topic, :tags)).to be_empty
      expect(topic.reload.tags).to contain_exactly(hidden_tag)
    end

    it "does not reveal a hidden tag when a category change is rejected" do
      hidden_tag = Fabricate(:tag)
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      topic.tags << hidden_tag
      allowed_tag = Fabricate(:tag)
      category = Fabricate(:category, allow_global_tags: false)
      category.allowed_tags = [allowed_tag.name]

      expect do
        described_class.call(
          arguments: {
            "topic_id" => topic.id,
            "category_id" => category.id,
          },
          request_context: request_context(user),
        )
      end.to raise_error(DiscourseMcp::ToolError) { |error|
        expect(error.message).not_to include(hidden_tag.name)
      }
    end

    it "changes a shared draft destination without moving the draft topic" do
      shared_drafts_category = Fabricate(:category)
      original_destination = Fabricate(:category)
      new_destination = Fabricate(:category)
      SiteSetting.shared_drafts_category = shared_drafts_category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:staff]
      topic.update!(category: shared_drafts_category)
      shared_draft = Fabricate(:shared_draft, topic:, category: original_destination)

      result =
        described_class.call(
          arguments: {
            "topic_id" => topic.id,
            "category_id" => new_destination.id,
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      expect(result[:updated_fields]).to eq(["category_id"])
      expect(result.dig(:topic, :destination_category_id)).to eq(new_destination.id)
      expect(topic.reload.category).to eq(shared_drafts_category)
      expect(shared_draft.reload.category).to eq(new_destination)
    end
  end

  describe "authored content" do
    fab!(:topic) { Fabricate(:topic, user:) }
    fab!(:post) { Fabricate(:post, topic:, user:) }

    it "does not allow author_username to impersonate another user" do
      expect do
        DiscourseMcp::Tools::ReplyTopic.call(
          arguments: {
            "topic_id" => topic.id,
            "raw" => "A complete reply body.",
            "author_username" => other_user.username,
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "creates a compatible topic and post response as the current user" do
      created_topic =
        DiscourseMcp::Tools::CreateTopic.call(
          arguments: {
            "title" => "A valid regular user topic",
            "raw" => "A complete topic body for this test.",
            "author_username" => user.username,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)
      created_post =
        DiscourseMcp::Tools::ReplyTopic.call(
          arguments: {
            "topic_id" => created_topic[:topic_id],
            "raw" => "A complete reply body for this test.",
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(created_topic[:id]).to be_a(Integer)
      expect(created_topic).to include(username: user.username, author_applied: true)
      expect(created_post).to include(topic_id: created_topic[:topic_id], post_number: 2)
    end

    it "updates a post only when the caller may edit it" do
      result =
        DiscourseMcp::Tools::EditPost.call(
          arguments: {
            "post_id" => post.id,
            "raw" => "An updated complete post body.",
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(id: post.id, raw: "An updated complete post body.")
      expect do
        DiscourseMcp::Tools::EditPost.call(
          arguments: {
            "post_id" => post.id,
            "raw" => "An unauthorized complete post body.",
          },
          request_context: request_context(other_user),
        )
      end.to raise_error(DiscourseMcp::ToolError)
    end
  end

  describe DiscourseMcp::Tools::SetPostDeleted do
    fab!(:topic) { Fabricate(:post, user:).topic }
    fab!(:post) { Fabricate(:post, topic:, user:) }

    it "deletes and recovers only the caller's post" do
      result =
        described_class.call(
          arguments: {
            "post_id" => post.id,
            "deleted" => true,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to eq(post_id: post.id, deleted: true)
      expect(post.reload.user_deleted).to eq(true)

      described_class.call(
        arguments: {
          "post_id" => post.id,
          "deleted" => false,
        },
        request_context: request_context(user),
      )
      expect(post.reload.user_deleted).to eq(false)

      [other_user, moderator, admin].each do |other_actor|
        expect do
          described_class.call(
            arguments: {
              "post_id" => post.id,
              "deleted" => true,
            },
            request_context: request_context(other_actor),
          )
        end.to raise_error(DiscourseMcp::ToolError)
      end
    end
  end

  describe DiscourseMcp::Tools::UpdateUser do
    it "lets a user update their own profile" do
      result =
        described_class.call(
          arguments: {
            "username" => user.username,
            "bio_raw" => "Updated profile",
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(success: true, username: user.username)
      expect(user.user_profile.reload.bio_raw).to eq("Updated profile")
    end

    it "does not turn staff access into permission to edit another profile" do
      [moderator, admin].each do |staff_user|
        expect do
          described_class.call(
            arguments: {
              "username" => user.username,
              "bio_raw" => "Staff edit",
            },
            request_context: request_context(staff_user),
          )
        end.to raise_error(Discourse::InvalidAccess)
      end
    end
  end

  describe DiscourseMcp::Tools::SetUserStatus do
    before { SiteSetting.enable_user_status = true }

    it "sets and clears only the caller's status" do
      result =
        described_class.call(
          arguments: {
            "description" => "Reviewing MCP tools",
            "emoji" => "mag",
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to eq(success: true)
      expect(user.reload.user_status).to have_attributes(
        description: "Reviewing MCP tools",
        emoji: "mag",
      )
      expect(other_user.user_status).to be_nil

      described_class.call(arguments: { "clear" => true }, request_context: request_context(user))
      expect(user.reload.user_status).to be_nil
    end
  end

  describe DiscourseMcp::Tools::UploadFile do
    it "creates a composer upload owned by the authenticated user" do
      image_data = Base64.strict_encode64(file_from_fixtures("logo.png").read)

      result =
        described_class.call(
          arguments: {
            "upload_type" => "composer",
            "image_data" => image_data,
            "filename" => "logo.png",
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result[:id]).to be_a(Integer)
      expect(result[:original_filename]).to eq("logo.png")
      expect(Upload.find(result[:id]).user_id).to eq(user.id)
    end

    it "does not accept another user's id" do
      expect do
        described_class.call(
          arguments: {
            "upload_type" => "avatar",
            "image_data" => Base64.strict_encode64("image"),
            "filename" => "image.png",
            "user_id" => other_user.id,
          },
          request_context: request_context(user),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe "private messages" do
    fab!(:message) { Fabricate(:private_message_post, user:, recipient: other_user) }

    before { SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

    it "lists only a mailbox the caller may access" do
      result =
        DiscourseMcp::Tools::ListPrivateMessages.call(
          arguments: {
            "username" => other_user.username,
          },
          request_context: request_context(other_user),
        ).fetch(:structuredContent)

      expect(result[:messages].pluck(:topic_id)).to include(message.topic_id)
      expect do
        DiscourseMcp::Tools::ListPrivateMessages.call(
          arguments: {
            "username" => other_user.username,
          },
          request_context: request_context(moderator),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "paginates a mailbox without skipping messages" do
      newer_message = Fabricate(:private_message_post, user:, recipient: other_user)
      newer_message.topic.update!(bumped_at: 1.minute.from_now)

      first_page =
        DiscourseMcp::Tools::ListPrivateMessages.call(
          arguments: {
            "per_page" => 1,
          },
          request_context: request_context(other_user),
        ).fetch(:structuredContent)
      second_page =
        DiscourseMcp::Tools::ListPrivateMessages.call(
          arguments: {
            "page" => 1,
            "per_page" => 1,
          },
          request_context: request_context(other_user),
        ).fetch(:structuredContent)

      expect(first_page[:messages].sole[:topic_id]).to eq(newer_message.topic_id)
      expect(first_page[:meta][:has_more]).to eq(true)
      expect(second_page[:messages].sole[:topic_id]).to eq(message.topic_id)
    end

    it "lists a group mailbox only for group members and admins" do
      group = Fabricate(:group, has_messages: true)
      group.add(other_user)
      group_message = Fabricate(:group_private_message_post, user:, recipients: group)

      [other_user, admin].each do |viewer|
        result =
          DiscourseMcp::Tools::ListPrivateMessages.call(
            arguments: {
              "username" => viewer.username,
              "group_name" => group.name,
            },
            request_context: request_context(viewer),
          ).fetch(:structuredContent)

        expect(result[:messages].pluck(:topic_id)).to include(group_message.topic_id)
      end

      expect do
        DiscourseMcp::Tools::ListPrivateMessages.call(
          arguments: {
            "username" => moderator.username,
            "group_name" => group.name,
          },
          request_context: request_context(moderator),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "reads a private message only for participants and admins" do
      expectations = { user => true, other_user => true, moderator => false, admin => true }

      expectations.each do |viewer, allowed|
        operation =
          lambda do
            DiscourseMcp::Tools::ReadPrivateMessage.call(
              arguments: {
                "topic_id" => message.topic_id,
              },
              request_context: request_context(viewer),
            )
          end

        if allowed
          expect(operation.call.dig(:structuredContent, :posts).sole[:id]).to eq(message.id)
        else
          expect(&operation).to raise_error(DiscourseMcp::ToolError)
        end
      end
    end

    it "rejects a public topic as a private message" do
      topic = Fabricate(:topic)

      expect do
        DiscourseMcp::Tools::ReadPrivateMessage.call(
          arguments: {
            "topic_id" => topic.id,
          },
          request_context: request_context(user),
        )
      end.to raise_error(DiscourseMcp::ToolError)
    end

    it "creates and replies to a private message as the authenticated user" do
      created =
        DiscourseMcp::Tools::CreatePrivateMessage.call(
          arguments: {
            "title" => "Private hello",
            "raw" => "First message",
            "usernames" => [other_user.username],
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)
      reply =
        DiscourseMcp::Tools::ReplyPrivateMessage.call(
          arguments: {
            "topic_id" => created[:topic_id],
            "raw" => "A complete private reply.",
          },
          request_context: request_context(other_user),
        ).fetch(:structuredContent)

      expect(created).to include(title: "Private hello")
      expect(reply).to include(topic_id: created[:topic_id], post_number: 2)
    end

    it "limits all recipient types together when creating a message" do
      group = Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone])
      SiteSetting.max_allowed_message_recipients = 1

      expect do
        DiscourseMcp::Tools::CreatePrivateMessage.call(
          arguments: {
            "title" => "Too many recipients",
            "raw" => "This message has too many recipients.",
            "usernames" => [other_user.username],
            "group_names" => [group.name],
          },
          request_context: request_context(user),
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t(:max_pm_recipients, recipients_limit: 1))
    end

    it "invites a user only when the caller may invite to the message" do
      invited_user = Fabricate(:user)
      result =
        DiscourseMcp::Tools::InviteToPrivateMessage.call(
          arguments: {
            "topic_id" => message.topic_id,
            "username" => invited_user.username,
          },
          request_context: request_context(user),
        ).fetch(:structuredContent)

      expect(result).to include(topic_id: message.topic_id, recipient_type: "user", status: "added")
      expect(message.topic.reload.allowed_users).to include(invited_user)

      expect do
        DiscourseMcp::Tools::InviteToPrivateMessage.call(
          arguments: {
            "topic_id" => message.topic_id,
            "username" => Fabricate(:user).username,
          },
          request_context: request_context(moderator),
        )
      end.to raise_error(DiscourseMcp::ToolError)
    end

    it "does not let a regular user invite a group after reaching the recipient limit" do
      group = Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone])
      SiteSetting.max_allowed_message_recipients = 2

      expect do
        DiscourseMcp::Tools::InviteToPrivateMessage.call(
          arguments: {
            "topic_id" => message.topic_id,
            "group_name" => group.name,
          },
          request_context: request_context(user),
        )
      end.to raise_error(
        DiscourseMcp::ToolError,
        I18n.t("pm_reached_recipients_limit", recipients_limit: 2),
      )
      expect(message.topic.reload.allowed_groups).to be_empty
    end

    it "lets staff invite a group after reaching the recipient limit" do
      group = Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone])
      SiteSetting.max_allowed_message_recipients = 2

      result =
        DiscourseMcp::Tools::InviteToPrivateMessage.call(
          arguments: {
            "topic_id" => message.topic_id,
            "group_name" => group.name,
          },
          request_context: request_context(admin),
        ).fetch(:structuredContent)

      expect(result).to include(recipient_type: "group", status: "added")
      expect(message.topic.reload.allowed_groups).to contain_exactly(group)
    end
  end
end

describe DiscourseMcp::CorePrimitives do
  it "declares an output schema for every tool" do
    tools_without_output_schema =
      DiscourseMcp.registry.all(:tool).reject(&:output_schema).map(&:identifier)

    expect(tools_without_output_schema).to be_empty
  end

  it "registers the compatible regular-user tool names" do
    expected_names = %w[
      discourse_create_post
      discourse_create_private_message
      discourse_create_topic
      discourse_get_user
      discourse_invite_to_private_message
      discourse_list_private_messages
      discourse_read_post
      discourse_read_private_message
      discourse_read_topic
      discourse_reply_private_message
      discourse_update_post
      discourse_update_topic
      discourse_update_user
      discourse_upload_file
    ]

    expect(expected_names).to all(satisfy { |name| DiscourseMcp.registry.find(:tool, name) })
    expect(DiscourseMcp.registry.find(:tool, "discourse_topic_get")).to be_nil
  end

  it "uses a separate write scope for profile updates" do
    primitive = DiscourseMcp.registry.find(:tool, "discourse_update_user")

    expect(primitive.required_scopes).to eq(["mcp:profile:write"])
  end

  it "uses separate scopes for private messages and drafts" do
    private_message_scopes =
      %w[
        discourse_list_private_messages
        discourse_read_private_message
        discourse_create_private_message
        discourse_reply_private_message
        discourse_invite_to_private_message
      ].to_h do |identifier|
        primitive = DiscourseMcp.registry.find(:tool, identifier)
        [identifier, primitive.required_scopes]
      end
    draft_scopes =
      %w[discourse_get_draft discourse_save_draft discourse_delete_draft].to_h do |identifier|
        primitive = DiscourseMcp.registry.find(:tool, identifier)
        [identifier, primitive.required_scopes]
      end

    expect(private_message_scopes).to eq(
      "discourse_list_private_messages" => ["mcp:private-messages:read"],
      "discourse_read_private_message" => ["mcp:private-messages:read"],
      "discourse_create_private_message" => ["mcp:private-messages:write"],
      "discourse_reply_private_message" => ["mcp:private-messages:write"],
      "discourse_invite_to_private_message" => ["mcp:private-messages:write"],
    )
    expect(draft_scopes).to eq(
      "discourse_get_draft" => ["mcp:drafts:read"],
      "discourse_save_draft" => ["mcp:drafts:write"],
      "discourse_delete_draft" => ["mcp:drafts:write"],
    )
  end

  it "requires renewed consent for tools that can affect external systems" do
    primitive_names = %w[
      discourse_create_private_message
      discourse_invite_to_private_message
      discourse_upload_file
    ]

    primitives = primitive_names.map { |name| DiscourseMcp.registry.find(:tool, name) }

    expect(primitives.map(&:risk)).to all(eq(:external_side_effect))
    expect(primitives.map { |primitive| primitive.annotations["openWorldHint"] }).to all(eq(true))
    expect(primitives).to all(be_consent_relevant)
  end
end
