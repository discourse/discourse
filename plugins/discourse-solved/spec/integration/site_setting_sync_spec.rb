# frozen_string_literal: true

# TODO: Remove this in 2026.5.0 once we've deployed the change from hours to days
# widely.
RSpec.describe "Solved auto-close setting sync" do
  it "syncs legacy hours when days changes" do
    SiteSetting.solved_topics_auto_close_hours = 0

    SiteSetting.solved_topics_auto_close_days = 2

    expect(SiteSetting.solved_topics_auto_close_hours).to eq(48)
  end

  it "syncs days when legacy hours changes using nearest-day rounding" do
    SiteSetting.solved_topics_auto_close_days = 0

    SiteSetting.solved_topics_auto_close_hours = 36
    expect(SiteSetting.solved_topics_auto_close_days).to eq(2)

    SiteSetting.solved_topics_auto_close_hours = 35
    expect(SiteSetting.solved_topics_auto_close_days).to eq(1)
  end
end
