# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::SendDefaultWelcomeMessage do
  let(:user) { Fabricate(:user) }

  it 'should send the right welcome message' do
    described_class.new.execute(user_id: user.id)

    topic = Topic.last

    expect(topic.title).to eq(I18n.t(
      "system_messages.welcome_user.subject_template",
      site_name: SiteSetting.title
    ))

    expect(topic.first_post.raw).to eq(I18n.t(
      "system_messages.welcome_user.text_body_template",
      SystemMessage.new(user).defaults
    ).chomp)

    expect(topic.closed).to eq(true)
  end

  describe 'for an invited user' do
    let(:invite) { Fabricate(:invite, user: user, redeemed_at: Time.zone.now) }

    it 'should send the right welcome message' do
      described_class.new.execute(user_id: invite.user_id)

      topic = Topic.last

      expect(topic.title).to eq(I18n.t(
        "system_messages.welcome_invite.subject_template",
        site_name: SiteSetting.title
      ))

      expect(topic.first_post.raw).to eq(I18n.t(
        "system_messages.welcome_invite.text_body_template",
        SystemMessage.new(user).defaults
      ).chomp)

      expect(topic.closed).to eq(true)
    end
  end
end
