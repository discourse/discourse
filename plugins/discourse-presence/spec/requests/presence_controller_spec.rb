# frozen_string_literal: true

RSpec.describe PresenceController do
  describe "#get" do
    fab!(:whisperers_group, :group)
    fab!(:private_group, :group)

    fab!(:authorized_whisperer) do
      Fabricate(:user).tap do |user|
        whisperers_group.add(user)
        private_group.add(user)
      end
    end

    fab!(:unauthorized_whisperer) { Fabricate(:user).tap { |user| whisperers_group.add(user) } }
    fab!(:private_category_user) { Fabricate(:user).tap { |user| private_group.add(user) } }

    fab!(:private_category) { Fabricate(:private_category, group: private_group) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }

    before do
      PresenceChannel.clear_all!
      SiteSetting.whispers_allowed_groups = whisperers_group.id.to_s
    end

    after { PresenceChannel.clear_all! }

    it "only shows whisper presence to users who can whisper and see the topic" do
      whisper_channel_name = "/discourse-presence/whisper/#{private_topic.id}"
      PresenceChannel.new(whisper_channel_name).present(
        user_id: authorized_whisperer.id,
        client_id: SecureRandom.hex,
      )

      sign_in(unauthorized_whisperer)

      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)

      sign_in(private_category_user)

      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)

      sign_in(authorized_whisperer)

      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      presence = response.parsed_body[whisper_channel_name]
      expect(presence["count"]).to eq(1)
      expect(presence["users"].map { |present_user| present_user["id"] }).to contain_exactly(
        authorized_whisperer.id,
      )
      expect(PresenceChannel.new(whisper_channel_name).config.allowed_user_ids).to contain_exactly(
        authorized_whisperer.id,
      )

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => true)
    end

    it "requires shared draft visibility for whisper presence" do
      shared_drafts_group = Fabricate(:group)
      shared_draft_viewer =
        Fabricate(:user).tap do |user|
          whisperers_group.add(user)
          private_group.add(user)
          shared_drafts_group.add(user)
        end
      shared_draft_topic = Fabricate(:topic, category: private_category)
      Fabricate(:shared_draft, topic: shared_draft_topic, category: Fabricate(:category))
      SiteSetting.shared_drafts_category = private_category.id
      SiteSetting.shared_drafts_allowed_groups = shared_drafts_group.id.to_s
      whisper_channel_name = "/discourse-presence/whisper/#{shared_draft_topic.id}"

      PresenceChannel.new(whisper_channel_name).present(
        user_id: shared_draft_viewer.id,
        client_id: SecureRandom.hex,
      )

      expect(authorized_whisperer.guardian.can_see?(shared_draft_topic)).to eq(false)
      expect(shared_draft_viewer.guardian.can_see?(shared_draft_topic)).to eq(true)

      sign_in(authorized_whisperer)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)

      sign_in(shared_draft_viewer)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body[whisper_channel_name]["count"]).to eq(1)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => true)
    end

    it "allows whisperers who can see shared drafts through a logged-in user group" do
      shared_draft_topic = Fabricate(:topic, category: private_category)
      Fabricate(:shared_draft, topic: shared_draft_topic, category: Fabricate(:category))
      SiteSetting.shared_drafts_category = private_category.id
      SiteSetting.shared_drafts_allowed_groups = Group::AUTO_GROUPS[:logged_in_users].to_s
      whisper_channel_name = "/discourse-presence/whisper/#{shared_draft_topic.id}"

      expect(authorized_whisperer.guardian.can_see?(shared_draft_topic)).to eq(true)

      sign_in(authorized_whisperer)
      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => true)
    end

    it "denies a whisper-enabled moderator outside a private message" do
      participant = Fabricate(:user)
      whisperers_group.add(participant)
      moderator = Fabricate(:moderator)
      whisperers_group.add(moderator)
      private_message = Fabricate(:private_message_topic, user: participant)
      whisper_channel_name = "/discourse-presence/whisper/#{private_message.id}"

      PresenceChannel.new(whisper_channel_name).present(
        user_id: participant.id,
        client_id: SecureRandom.hex,
      )

      sign_in(moderator)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)

      sign_in(participant)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(
        response.parsed_body[whisper_channel_name]["users"].map { |user| user["id"] },
      ).to contain_exactly(participant.id)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => true)

      admin = Fabricate(:admin)
      whisperers_group.add(admin)
      PresenceChannel.clear_all!
      PresenceChannel.new(whisper_channel_name).present(
        user_id: participant.id,
        client_id: SecureRandom.hex,
      )
      sign_in(admin)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body[whisper_channel_name]["count"]).to eq(1)

      SiteSetting.suppress_secured_categories_from_admin = true
      PresenceChannel.clear_all!
      PresenceChannel.new(whisper_channel_name).present(
        user_id: participant.id,
        client_id: SecureRandom.hex,
      )

      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)
    end

    it "allows whisperers who receive private message access through an allowed group" do
      participant_group = Fabricate(:group)
      participant = Fabricate(:user)
      participant_group.add(participant)
      whisperers_group.add(participant)
      private_message = Fabricate(:private_message_topic, allowed_groups: [participant_group])
      whisper_channel_name = "/discourse-presence/whisper/#{private_message.id}"

      PresenceChannel.new(whisper_channel_name).present(
        user_id: participant.id,
        client_id: SecureRandom.hex,
      )

      sign_in(participant)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body[whisper_channel_name]["count"]).to eq(1)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => true)
    end

    it "honors suppressed category visibility for whisper-enabled admins" do
      admin = Fabricate(:admin)
      whisperers_group.add(admin)
      whisper_channel_name = "/discourse-presence/whisper/#{private_topic.id}"
      SiteSetting.suppress_secured_categories_from_admin = true

      PresenceChannel.new(whisper_channel_name).present(
        user_id: authorized_whisperer.id,
        client_id: SecureRandom.hex,
      )

      sign_in(admin)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)
    end

    it "allows whisper-enabled moderators to view and enter flagged and official-warning PM channels" do
      participant = Fabricate(:user)
      moderator = Fabricate(:moderator)
      whisperers_group.add(participant)
      whisperers_group.add(moderator)

      flagged_private_message = Fabricate(:private_message_topic, user: participant)
      flagged_post = Fabricate(:post, topic: flagged_private_message, user: participant)
      Fabricate(:reviewable_flagged_post, topic: flagged_private_message, target: flagged_post)

      official_warning_private_message =
        Fabricate(
          :private_message_topic,
          user: participant,
          subtype: TopicSubtype.moderator_warning,
        )

      [flagged_private_message, official_warning_private_message].each do |private_message|
        channel_name = "/discourse-presence/whisper/#{private_message.id}"
        PresenceChannel.new(channel_name).present(
          user_id: participant.id,
          client_id: SecureRandom.hex,
        )

        expect(moderator.guardian.can_see?(private_message)).to eq(true)

        sign_in(moderator)
        get "/presence/get", params: { channels: [channel_name] }

        expect(response.status).to eq(200)
        expect(response.parsed_body[channel_name]["count"]).to eq(1)

        post "/presence/update.json",
             params: {
               client_id: SecureRandom.hex,
               present_channels: [channel_name],
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(channel_name => true)
      end
    end

    it "keeps public whisper presence available only to whisperers" do
      public_topic = Fabricate(:topic)
      outsider = Fabricate(:user)
      whisper_channel_name = "/discourse-presence/whisper/#{public_topic.id}"

      PresenceChannel.new(whisper_channel_name).present(
        user_id: authorized_whisperer.id,
        client_id: SecureRandom.hex,
      )

      sign_in(authorized_whisperer)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      presence = response.parsed_body[whisper_channel_name]
      expect(presence["count"]).to eq(1)
      expect(presence["users"].map { |user| user["id"] }).to contain_exactly(
        authorized_whisperer.id,
      )

      sign_in(outsider)
      get "/presence/get", params: { channels: [whisper_channel_name] }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => nil)

      post "/presence/update.json",
           params: {
             client_id: SecureRandom.hex,
             present_channels: [whisper_channel_name],
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(whisper_channel_name => false)
    end

    it "uses matching groups without materializing their members for restricted channels" do
      shared_group = Fabricate(:group)
      users = Fabricate.times(10, :user)
      users.each { |user| shared_group.add(user) }
      topics =
        Fabricate.times(50, :topic, category: Fabricate(:private_category, group: shared_group))
      channel_names = topics.map { |topic| "/discourse-presence/whisper/#{topic.id}" }
      SiteSetting.whispers_allowed_groups = shared_group.id.to_s

      sign_in(users.first)
      get "/presence/get", params: { channels: channel_names }

      expect(response.status).to eq(200)
      expect(response.parsed_body.values).to all(be_truthy)
      expect(
        channel_names.map { |name| PresenceChannel.new(name).config.allowed_user_ids }.uniq,
      ).to eq([nil])
      expect(
        channel_names.map { |name| PresenceChannel.new(name).config.allowed_group_ids }.uniq,
      ).to eq([[shared_group.id]])
    end
  end
end
