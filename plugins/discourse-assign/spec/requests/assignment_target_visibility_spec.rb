# frozen_string_literal: true

RSpec.describe "Assignment target visibility", type: :request do
  fab!(:assign_group, :group)
  fab!(:participant) { Fabricate(:user, groups: [assign_group]) }
  fab!(:outsider) { Fabricate(:user, groups: [assign_group]) }
  fab!(:recipient, :user)
  fab!(:private_message_post) do
    Fabricate(:private_message_post, user: participant, recipient: recipient)
  end

  let(:private_message) { private_message_post.topic }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
  end

  it "does not broadcast a private message note to an assigner who cannot see it" do
    channel = "/staff/topic-assignment"
    note = "confidential private message note #{SecureRandom.hex}"
    last_id = MessageBus.last_id(channel)

    sign_in(participant)
    put "/assign/assign.json",
        params: {
          target_id: private_message.id,
          target_type: "Topic",
          username: participant.username,
          note: note,
        }
    expect(response.status).to eq(200)

    sign_in(outsider)
    expect(outsider.guardian.can_see_topic?(private_message)).to eq(false)
    get "/t/#{private_message.id}.json"
    expect(response.status).to eq(404)

    expect(channel_messages(outsider, channel, last_id)).to be_empty
    expect(
      channel_messages(participant, channel, last_id).map { |m| m.dig("data", "assignment_note") },
    ).to include(note)
  end

  it "does not broadcast a restricted category note to an assigner outside the category" do
    category_group = Fabricate(:group)
    private_category = Fabricate(:private_category, group: category_group)
    category_group.add(participant)
    topic = Fabricate(:topic_with_op, category: private_category, user: participant)
    channel = "/staff/topic-assignment"
    note = "restricted category note #{SecureRandom.hex}"
    last_id = MessageBus.last_id(channel)

    sign_in(participant)
    put "/assign/assign.json",
        params: {
          target_id: topic.id,
          target_type: "Topic",
          username: participant.username,
          note: note,
        }
    expect(response.status).to eq(200)

    sign_in(outsider)
    expect(outsider.guardian.can_see_topic?(topic)).to eq(false)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(404)

    expect(channel_messages(outsider, channel, last_id)).to be_empty
    expect(
      channel_messages(participant, channel, last_id).map { |m| m.dig("data", "assignment_note") },
    ).to include(note)
  end

  describe "post assignments in topic JSON" do
    fab!(:admin)
    fab!(:topic)
    fab!(:whisper) { Fabricate(:post, topic: topic, user: admin, post_type: Post.types[:whisper]) }

    before { SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s }

    it "does not expose a whisper assignment to a non-whisperer" do
      note = "confidential whisper note #{SecureRandom.hex}"

      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: whisper.id,
            target_type: "Post",
            username: admin.username,
            note: note,
          }
      expect(response.status).to eq(200)

      sign_in(outsider)
      expect(outsider.guardian.can_see_post?(whisper.reload)).to eq(false)
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("post_stream", "posts").map { |p| p["id"] }).not_to include(
        whisper.id,
      )
      expect(response.parsed_body["indirectly_assigned_to"]).to be_blank

      sign_in(admin)
      get "/t/#{topic.id}.json"
      expect(
        response.parsed_body.dig("indirectly_assigned_to", whisper.id.to_s, "assignment_note"),
      ).to eq(note)
    end

    it "does not broadcast a whisper assignment to an assigner who cannot see the post" do
      channel = "/staff/topic-assignment"
      note = "confidential whisper note #{SecureRandom.hex}"
      last_id = MessageBus.last_id(channel)

      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: whisper.id,
            target_type: "Post",
            username: admin.username,
            note: note,
          }
      expect(response.status).to eq(200)

      expect(channel_messages(outsider, channel, last_id)).to be_empty
    end

    it "does not broadcast a whisper unassignment to an assigner who cannot see the post" do
      channel = "/staff/topic-assignment"

      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: whisper.id,
            target_type: "Post",
            username: admin.username,
          }
      expect(response.status).to eq(200)

      last_id = MessageBus.last_id(channel)
      put "/assign/unassign.json", params: { target_id: whisper.id, target_type: "Post" }
      expect(response.status).to eq(200)

      expect(channel_messages(outsider, channel, last_id)).to be_empty
    end

    it "does not expose a whisper assignment in topic lists" do
      note = "confidential whisper note #{SecureRandom.hex}"

      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: whisper.id,
            target_type: "Post",
            username: admin.username,
            note: note,
          }
      expect(response.status).to eq(200)

      sign_in(outsider)
      get "/latest.json"
      expect(topic_from(response.parsed_body.dig("topic_list", "topics"))).not_to have_key(
        "indirectly_assigned_to",
      )

      sign_in(admin)
      get "/latest.json"
      expect(
        topic_from(response.parsed_body.dig("topic_list", "topics")).dig(
          "indirectly_assigned_to",
          whisper.id.to_s,
          "assigned_to",
          "username",
        ),
      ).to eq(admin.username)
    end

    def topic_from(topics)
      topics.find { |item| item["id"] == topic.id }
    end

    context "with assigns_public enabled" do
      before { SiteSetting.assigns_public = true }

      it "does not expose a whisper assignment note in a public tracking post" do
        note = "confidential whisper note #{SecureRandom.hex}"

        sign_in(admin)
        put "/assign/assign.json",
            params: {
              target_id: whisper.id,
              target_type: "Post",
              username: admin.username,
              note: note,
            }
        expect(response.status).to eq(200)

        sign_in(outsider)
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(post_stream_cooked.join).not_to include(note)

        sign_in(admin)
        get "/t/#{topic.id}.json"
        expect(post_stream_cooked.join).to include(note)
      end

      it "does not expose a whisper assignment note update in a public tracking post" do
        note = "confidential whisper note #{SecureRandom.hex}"
        updated_note = "updated whisper note #{SecureRandom.hex}"

        sign_in(admin)
        put "/assign/assign.json",
            params: {
              target_id: whisper.id,
              target_type: "Post",
              username: admin.username,
              note: note,
            }
        expect(response.status).to eq(200)

        put "/assign/assign.json",
            params: {
              target_id: whisper.id,
              target_type: "Post",
              username: admin.username,
              note: updated_note,
            }
        expect(response.status).to eq(200)

        sign_in(outsider)
        get "/t/#{topic.id}.json"
        expect(post_stream_cooked.join).not_to include(updated_note)

        sign_in(admin)
        get "/t/#{topic.id}.json"
        expect(post_stream_cooked.join).to include(updated_note)
      end

      it "does not expose whisper unassignment tracking to non-whisperers" do
        sign_in(admin)
        put "/assign/assign.json",
            params: {
              target_id: whisper.id,
              target_type: "Post",
              username: admin.username,
            }
        expect(response.status).to eq(200)

        put "/assign/unassign.json", params: { target_id: whisper.id, target_type: "Post" }
        expect(response.status).to eq(200)

        sign_in(outsider)
        get "/t/#{topic.id}.json"
        expect(post_stream.map { |post| post["action_code_path"] }).not_to include(
          "/p/#{whisper.id}",
        )

        sign_in(admin)
        get "/t/#{topic.id}.json"
        expect(post_stream.map { |post| post["action_code_path"] }).to include("/p/#{whisper.id}")
      end

      it "keeps public tracking posts for posts the whole topic audience can see" do
        note = "public assignment note #{SecureRandom.hex}"
        post = Fabricate(:post, topic: topic, user: admin)

        sign_in(admin)
        put "/assign/assign.json",
            params: {
              target_id: post.id,
              target_type: "Post",
              username: admin.username,
              note: note,
            }
        expect(response.status).to eq(200)

        sign_in(outsider)
        get "/t/#{topic.id}.json"
        expect(post_stream_cooked.join).to include(note)
      end

      def post_stream
        response.parsed_body.dig("post_stream", "posts")
      end

      def post_stream_cooked
        post_stream.map { |post| post["cooked"] }
      end
    end
  end

  describe "tracking posts for post targets the topic audience cannot see" do
    fab!(:admin)
    fab!(:topic)
    fab!(:hidden_post) { Fabricate(:post, topic: topic, user: admin, hidden: true) }
    fab!(:whisper_group, :group)
    fab!(:whisper_reader) { Fabricate(:user, groups: [whisper_group]) }

    before do
      SiteSetting.assigns_public = true
      SiteSetting.whispers_allowed_groups = whisper_group.id.to_s
    end

    it "does not expose a hidden post's assignment note or link to whisperers" do
      note = "hidden post note #{SecureRandom.hex}"

      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: hidden_post.id,
            target_type: "Post",
            username: admin.username,
            note: note,
          }
      expect(response.status).to eq(200)

      sign_in(whisper_reader)
      expect(whisper_reader.guardian.can_see_post?(hidden_post.reload)).to eq(false)
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)

      expect(post_stream_cooked.join).not_to include(note)
      expect(post_stream.map { |post| post["action_code_path"] }).not_to include(
        "/p/#{hidden_post.id}",
      )
    end

    it "does not expose a hidden post's updated note to whisperers" do
      sign_in(admin)
      put "/assign/assign.json",
          params: {
            target_id: hidden_post.id,
            target_type: "Post",
            username: admin.username,
            note: "initial note",
          }
      expect(response.status).to eq(200)

      updated_note = "updated hidden note #{SecureRandom.hex}"
      put "/assign/assign.json",
          params: {
            target_id: hidden_post.id,
            target_type: "Post",
            username: admin.username,
            note: updated_note,
          }
      expect(response.status).to eq(200)

      sign_in(whisper_reader)
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)
      expect(post_stream_cooked.join).not_to include(updated_note)
    end

    def post_stream
      response.parsed_body.dig("post_stream", "posts")
    end

    def post_stream_cooked
      post_stream.map { |post| post["cooked"] }
    end
  end

  describe "private message assignment tracking" do
    fab!(:assignee_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
    let(:channel) { "/private-messages/assigned" }

    before do
      Jobs.run_immediately!
      assignee_group.add(participant)
    end

    it "does not deliver unassign tracking to a group member who cannot see the PM" do
      sign_in(participant)
      put "/assign/assign.json",
          params: {
            target_id: private_message.id,
            target_type: "Topic",
            group_name: assignee_group.name,
          }
      expect(response.status).to eq(200)

      assignee_group.add(outsider)
      expect(outsider.guardian.can_see_topic?(private_message)).to eq(false)

      last_id = MessageBus.last_id(channel)
      sign_in(participant)
      put "/assign/unassign.json", params: { target_id: private_message.id, target_type: "Topic" }
      expect(response.status).to eq(200)

      expect(channel_messages(outsider, channel, last_id)).to be_empty
      expect(channel_messages(participant, channel, last_id)).to include(
        include("data" => { "topic_id" => private_message.id }),
      )
    end

    it "does not deliver archive tracking to a group member who cannot see the PM" do
      sign_in(participant)
      put "/assign/assign.json",
          params: {
            target_id: private_message.id,
            target_type: "Topic",
            group_name: assignee_group.name,
          }
      expect(response.status).to eq(200)

      acting_group = Fabricate(:group)
      actor = Fabricate(:user, groups: [acting_group])
      private_message.topic_allowed_groups.create!(group: acting_group)
      assignee_group.add(outsider)
      expect(outsider.guardian.can_see_topic?(private_message)).to eq(false)

      last_id = MessageBus.last_id(channel)
      sign_in(actor)
      put "/t/#{private_message.id}/archive-message.json"
      expect(response.status).to eq(200)

      expect(channel_messages(outsider, channel, last_id)).to be_empty
      expect(channel_messages(participant, channel, last_id)).to include(
        include("data" => { "topic_id" => private_message.id }),
      )
    end
  end

  describe "group assignment counts" do
    fab!(:counted_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
    fab!(:counted_member) { Fabricate(:user, groups: [counted_group]) }
    fab!(:hidden_category_group, :group)
    fab!(:hidden_category) { Fabricate(:private_category, group: hidden_category_group) }
    fab!(:visible_topic, :topic)
    fab!(:hidden_topic) { Fabricate(:topic_with_op, category: hidden_category) }
    fab!(:hidden_private_message) { Fabricate(:private_message_post, user: recipient).topic }
    fab!(:admin)

    before do
      Fabricate(
        :topic_assignment,
        topic: visible_topic,
        target: visible_topic,
        assigned_to: counted_member,
        assigned_by_user: participant,
      )
      Fabricate(
        :topic_assignment,
        topic: hidden_topic,
        target: hidden_topic,
        assigned_to: counted_member,
        assigned_by_user: participant,
      )
      Fabricate(
        :topic_assignment,
        topic: hidden_private_message,
        target: hidden_private_message,
        assigned_to: counted_group,
        assigned_by_user: participant,
      )
    end

    it "scopes the group members counts to topics the assigner can see" do
      sign_in(outsider)
      expect(outsider.guardian.can_see_topic?(hidden_topic)).to eq(false)
      expect(outsider.guardian.can_see_topic?(hidden_private_message)).to eq(false)

      get "/assign/members/#{counted_group.name}.json"
      expect(response.status).to eq(200)
      member = response.parsed_body["members"].find { |m| m["id"] == counted_member.id }
      expect(member["assignments_count"]).to eq(1)
      expect(response.parsed_body["assignment_count"]).to eq(1)
      expect(response.parsed_body["group_assignment_count"]).to eq(0)

      sign_in(admin)
      get "/assign/members/#{counted_group.name}.json"
      expect(
        response.parsed_body["members"].find { |m| m["id"] == counted_member.id }[
          "assignments_count"
        ],
      ).to eq(2)
      expect(response.parsed_body["assignment_count"]).to eq(3)
      expect(response.parsed_body["group_assignment_count"]).to eq(1)
    end

    it "scopes the group serializer count to topics the assigner can see" do
      sign_in(outsider)
      get "/g/#{counted_group.name}.json"
      expect(response.parsed_body.dig("group", "assignment_count")).to eq(1)

      sign_in(admin)
      get "/g/#{counted_group.name}.json"
      expect(response.parsed_body.dig("group", "assignment_count")).to eq(3)
    end

    it "counts assignments in private messages the assigner participates in" do
      hidden_private_message.topic_allowed_users.create!(user: participant)

      sign_in(participant)
      expect(participant.guardian.can_see_topic?(hidden_private_message)).to eq(true)

      get "/assign/members/#{counted_group.name}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["group_assignment_count"]).to eq(1)

      get "/g/#{counted_group.name}.json"
      expect(response.parsed_body.dig("group", "assignment_count")).to eq(2)
    end

    context "with a shared draft in a readable category" do
      fab!(:draft_group, :group)
      fab!(:draft_category, :category)
      fab!(:draft) do
        Fabricate(:shared_draft, topic: Fabricate(:topic_with_op, category: draft_category))
      end

      before do
        SiteSetting.shared_drafts_category = draft_category.id
        SiteSetting.shared_drafts_allowed_groups = draft_group.id.to_s
        Fabricate(
          :topic_assignment,
          topic: draft.topic,
          assigned_to: counted_member,
          assigned_by_user: admin,
        )
      end

      it "excludes the draft from both counts unless the viewer can see shared drafts" do
        sign_in(outsider)
        expect(outsider.guardian.can_see_topic?(draft.topic)).to eq(false)
        get "/assign/members/#{counted_group.name}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["assignment_count"]).to eq(1)
        get "/g/#{counted_group.name}.json"
        expect(response.parsed_body.dig("group", "assignment_count")).to eq(1)

        draft_group.add(outsider)
        sign_in(outsider)
        expect(Guardian.new(outsider.reload).can_see_topic?(draft.topic)).to eq(true)
        get "/assign/members/#{counted_group.name}.json"
        expect(response.parsed_body["assignment_count"]).to eq(2)
        get "/g/#{counted_group.name}.json"
        expect(response.parsed_body.dig("group", "assignment_count")).to eq(2)
      end
    end

    context "with assignments to posts the assigner cannot see" do
      fab!(:member_whisper) do
        Fabricate(:post, topic: visible_topic, user: admin, post_type: Post.types[:whisper])
      end
      fab!(:group_whisper) do
        Fabricate(:post, topic: visible_topic, user: admin, post_type: Post.types[:whisper])
      end

      before do
        SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
        Fabricate(
          :post_assignment,
          post: member_whisper,
          assigned_to: counted_member,
          assigned_by_user: participant,
        )
        Fabricate(
          :post_assignment,
          post: group_whisper,
          assigned_to: counted_group,
          assigned_by_user: participant,
        )
      end

      it "does not count invisible post assignments for a non-whisperer" do
        sign_in(outsider)
        expect(outsider.guardian.can_see_post?(member_whisper)).to eq(false)
        expect(outsider.guardian.can_see_post?(group_whisper)).to eq(false)

        get "/assign/members/#{counted_group.name}.json"
        expect(response.status).to eq(200)
        expect(
          response.parsed_body["members"].find { |m| m["id"] == counted_member.id }[
            "assignments_count"
          ],
        ).to eq(1)
        expect(response.parsed_body["assignment_count"]).to eq(1)
        expect(response.parsed_body["group_assignment_count"]).to eq(0)

        get "/g/#{counted_group.name}.json"
        expect(response.parsed_body.dig("group", "assignment_count")).to eq(1)
      end

      it "counts the visible post assignments for an admin" do
        sign_in(admin)

        get "/assign/members/#{counted_group.name}.json"
        expect(response.status).to eq(200)
        expect(
          response.parsed_body["members"].find { |m| m["id"] == counted_member.id }[
            "assignments_count"
          ],
        ).to eq(3)
        expect(response.parsed_body["group_assignment_count"]).to eq(2)

        get "/g/#{counted_group.name}.json"
        expect(response.parsed_body.dig("group", "assignment_count")).to eq(5)
      end
    end
  end

  def channel_messages(viewer, channel, last_id)
    sign_in(viewer)
    post "/message-bus/#{SecureRandom.hex}/poll?dlp=t", params: { channel => last_id }
    expect(response.status).to eq(200)
    response.parsed_body.select { |message| message["channel"] == channel }
  end
end
