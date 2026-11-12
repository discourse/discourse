# frozen_string_literal: true

require "system_message"
require "topic_subtype"

RSpec.describe SystemMessage do
  describe "#create" do
    fab!(:admin)
    fab!(:user)

    before { SiteSetting.site_contact_username = admin.username }

    it "appends a paragraph in the recipient locale to a custom body before the plugin event" do
      SiteSetting.allow_user_locale = true
      user.update!(locale: "fr")
      TranslationOverride.upsert!(:fr, "system_messages.private_topic_title", "Sujet %{id}")
      expected_raw = "Custom outcome.\n\nSujet 42"

      event =
        DiscourseEvent.track(:before_system_message_sent) do
          SystemMessage.create(
            user,
            :plugin_notice,
            message_title: "Custom notice",
            message_raw: "Custom outcome.",
            body_suffix_key: "system_messages.private_topic_title",
            id: 42,
          )
        end

      expect(Post.last.raw).to eq(expected_raw)
      expect(event[:params].first[:post_creator_args].last[:raw]).to eq(expected_raw)
    end

    it "adds the rule in the recipient locale without changing the existing body or subject" do
      enable_dsa_reporting
      SiteSetting.allow_user_locale = true
      user.update!(locale: "fr")
      TranslationOverride.upsert!(
        :fr,
        "system_messages.moderation_reason",
        "Plus précisément : **%{ground}**. %{explanation}",
      )
      rule = { "ground" => "Be respectful", "explanation" => "No personal attacks." }
      params = { url: "/t/example/123/2", flag_reason: "Original reason.", edit_delay: 5 }
      baseline = SystemMessage.create(user, :post_hidden, params)

      notice = SystemMessage.create(user, :post_hidden, params.merge(dsa_community_rule: rule))

      expected_reason =
        "#{params[:flag_reason]}\n\nPlus précisément : **#{rule["ground"]}**. #{rule["explanation"]}"
      expect(notice.raw).to eq(baseline.raw.sub(params[:flag_reason], expected_reason))
      expect(notice.topic.title).to eq(baseline.topic.title)
    end

    it "preserves existing moderation notices exactly with DSA disabled or no rule selected" do
      %i[
        post_hidden
        post_hidden_again
        flags_agreed_and_post_deleted
        flags_agreed_and_post_deleted_for_responders
      ].each do |type|
        params = {
          url: "/t/example/123/2",
          flag_reason: "Original reason.",
          edit_delay: 5,
          flagged_post_raw_content: "Original post.",
          flagged_post_response_raw_content: "Reply.",
        }
        baseline = SystemMessage.create(user, type, params)
        enable_dsa_reporting
        unclassified = SystemMessage.create(user, type, params)
        SiteSetting.dsa_reporting_enabled = false
        disabled =
          SystemMessage.create(
            user,
            type,
            params.merge(dsa_community_rule: { ground: "Rule", explanation: "Explanation." }),
          )

        expect(unclassified.raw).to eq(baseline.raw)
        expect(disabled.raw).to eq(baseline.raw)
        expect(unclassified.topic.title).to eq(baseline.topic.title)
        expect(disabled.topic.title).to eq(baseline.topic.title)
      end
    end

    it "creates the expected post" do
      system_message = SystemMessage.new(user)
      post = system_message.create(:welcome_invite)
      topic = post.topic

      expect(topic.private_message?).to eq(true)
      expect(topic.subtype).to eq(TopicSubtype.system_message)

      expect(topic.allowed_users.pluck(:user_id)).to contain_exactly(user.id, admin.id)

      expect(UserArchivedMessage.where(user_id: admin.id, topic_id: topic.id).count).to eq(1)
    end

    it "can create a post from system user in user selected locale" do
      SiteSetting.allow_user_locale = true
      user_de = Fabricate(:user, locale: "de")
      system_user = Discourse.system_user

      post = SystemMessage.create_from_system_user(user_de, :welcome_invite)
      topic = post.topic

      expect(topic.private_message?).to eq(true)
      expect(topic.title).to eq(
        I18n.with_locale(:de) do
          I18n.t("system_messages.welcome_invite.subject_template", site_name: SiteSetting.title)
        end,
      )
      expect(topic.subtype).to eq(TopicSubtype.system_message)

      expect(topic.allowed_users.pluck(:user_id)).to contain_exactly(user_de.id, system_user.id)

      expect(UserArchivedMessage.where(user_id: system_user.id, topic_id: topic.id).count).to eq(0)
    end

    it "allows message_title and message_raw ops to override content" do
      user = Fabricate(:user)
      system_user = Discourse.system_user

      post =
        SystemMessage.create_from_system_user(
          user,
          :welcome_invite,
          { message_title: "override title", message_raw: "override body" },
        )
      topic = post.topic

      expect(topic.private_message?).to eq(true)
      expect(topic.title).to eq("override title")
      expect(topic.subtype).to eq(TopicSubtype.system_message)
      expect(post.raw).to eq("override body")
    end

    it "invites the site contact group" do
      group = Fabricate(:group)
      SiteSetting.site_contact_group_name = group.id.to_s

      post = SystemMessage.create(user, :welcome_invite)
      expect(post.topic.allowed_groups).to contain_exactly(group)
    end

    it "sends event with post object" do
      system_message = SystemMessage.new(user)

      event =
        DiscourseEvent.track(:system_message_sent) { system_message.create(:tl2_promotion_message) }

      expect(event[:event_name]).to eq(:system_message_sent)
      expect(event[:params].first[:post]).to eq(Post.last)
      expect(event[:params].first[:message_type]).to eq(:tl2_promotion_message)
      expect(event[:params].first[:recipient]).to eq(user)
    end

    it "sends an event before the system message is sent" do
      system_message = SystemMessage.new(user)

      event =
        DiscourseEvent.track(:before_system_message_sent) do
          system_message.create(:tl2_promotion_message)
        end

      expect(event[:event_name]).to eq(:before_system_message_sent)
      expect(event[:params].first[:message_type]).to eq(:tl2_promotion_message)
      expect(event[:params].first[:recipient]).to eq(user)
    end
  end
end
