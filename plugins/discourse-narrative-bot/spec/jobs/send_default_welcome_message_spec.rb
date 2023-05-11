# frozen_string_literal: true

RSpec.describe Jobs::SendDefaultWelcomeMessage do
  let(:user) { Fabricate(:user) }

  it "should send the right welcome message" do
    described_class.new.execute(user_id: user.id)

    topic = Topic.last

    expect(topic.title).to eq(
      I18n.t("system_messages.welcome_user.subject_template", site_name: SiteSetting.title),
    )

    expect(topic.first_post.raw).to eq(
      I18n.t(
        "system_messages.welcome_user.text_body_template",
        SystemMessage.new(user).defaults,
      ).chomp,
    )

    expect(topic.closed).to eq(true)
  end

  describe "for an invited user" do
    let(:invite) { Fabricate(:invite, email: "foo@bar.com") }
    let(:invited_user) do
      Fabricate(
        :invited_user,
        invite: invite,
        user: Fabricate(:user, email: "foo@bar.com"),
        redeemed_at: Time.zone.now,
      )
    end

    it "should send the right welcome message" do
      described_class.new.execute(user_id: invited_user.user_id)

      topic = Topic.last

      expect(topic.title).to eq(
        I18n.t("system_messages.welcome_invite.subject_template", site_name: SiteSetting.title),
      )

      expect(topic.first_post.raw).to eq(
        I18n.t(
          "system_messages.welcome_invite.text_body_template",
          SystemMessage.new(invited_user.user).defaults,
        ).chomp,
      )

      expect(topic.closed).to eq(true)
    end
  end
end
