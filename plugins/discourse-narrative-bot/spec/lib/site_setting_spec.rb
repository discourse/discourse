# frozen_string_literal: true

RSpec.describe SiteSetting do
  let(:narrative_bot) { ::DiscourseNarrativeBot::Base.new }
  let(:discobot_user) { narrative_bot.discobot_user }

  before { SiteSetting.discourse_narrative_bot_enabled = true }

  it "should update bot's `UserProfile#bio_raw` when `default_locale` site setting is changed" do
    expect(discobot_user.user_profile.bio_raw).to eq(
      I18n.with_locale(:en) { I18n.t("discourse_narrative_bot.bio") },
    )

    SiteSetting.default_locale = "zh_CN"

    expect(discobot_user.user_profile.reload.bio_raw).to eq(
      I18n.with_locale(:zh_CN) { I18n.t("discourse_narrative_bot.bio") },
    )
  end
end
