# frozen_string_literal: true

RSpec.describe Jobs::SendAdvancedTutorialMessage do
  before do
    Jobs.run_immediately!
    SiteSetting.discourse_narrative_bot_enabled = true
  end

  it 'sends a message to the promoted user' do
    user = Fabricate(:user)
    system_user = Discourse.system_user
    Jobs.enqueue(:send_advanced_tutorial_message, user_id: user.id)

    topic = Topic.last

    expect(topic).not_to be_nil
    expect(topic.user).to eq(system_user)
    expect(topic.archetype).to eq(Archetype.private_message)
    expect(topic.topic_allowed_users.pluck(:user_id)).to contain_exactly(
      system_user.id, user.id
    )
    expect(topic.first_post.raw).to eq(I18n.t(
      'discourse_narrative_bot.tl2_promotion_message.text_body_template',
      discobot_username: ::DiscourseNarrativeBot::Base.new.discobot_user.username,
      reset_trigger: "#{::DiscourseNarrativeBot::TrackSelector.reset_trigger} #{::DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger}"
    ).chomp)
  end
end
