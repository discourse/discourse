# frozen_string_literal: true

require Rails.root.join(
          "plugins/live/db/post_migrate/20261020161054_finish_rename_voice_to_live.rb",
        )

RSpec.describe FinishRenameVoiceToLive do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "moves badges left in a Voice grouping into the existing Live grouping" do
    live = BadgeGrouping.find_or_create_by!(name: "Live") { |g| g.position = 15 }
    voice = BadgeGrouping.create!(name: "Voice", position: 42, description: "Calls and rooms")
    badge = Fabricate(:badge, badge_grouping_id: voice.id)

    described_class.new.up

    expect(badge.reload.badge_grouping_id).to eq(live.id)
    expect(live.reload).to have_attributes(position: 42, description: "Calls and rooms")
    expect(BadgeGrouping.exists?(voice.id)).to eq(false)
  end
end
