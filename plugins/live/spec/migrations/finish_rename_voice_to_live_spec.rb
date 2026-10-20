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

  context "with rows the voice code wrote during the deploy" do
    fab!(:session, :live_session)

    def flag_session(type, target_type)
      reviewable = Fabricate(:reviewable)
      DB.exec(
        "UPDATE reviewables SET type = ?, target_type = ?, target_id = ? WHERE id = ?",
        type,
        target_type,
        session.id,
        reviewable.id,
      )
      reviewable.id
    end

    it "converts them to the live names" do
      flag_id = flag_session("ReviewableVoiceUser", "Voice::Session")
      thread = Fabricate(:chat_thread)
      thread.upsert_custom_fields("voice_room_id" => 7)
      PluginStore.set("voice", "livekit_agent_bot_id", 42)

      described_class.new.up

      expect(
        DB.query_single(
          "SELECT type, type_source, target_type FROM reviewables WHERE id = ?",
          flag_id,
        ),
      ).to eq(%w[ReviewableLiveUser live Live::Session])
      expect(thread.reload.custom_fields).to eq("live_room_id" => "7")
      expect(PluginStore.get("live", "livekit_agent_bot_id")).to eq(42)
    end

    it "leaves a voice flag alone when the session already has a live one" do
      flag_session("ReviewableLiveUser", "Live::Session")
      voice_flag_id = flag_session("ReviewableVoiceUser", "Voice::Session")

      described_class.new.up

      expect(DB.query_single("SELECT type FROM reviewables WHERE id = ?", voice_flag_id)).to eq(
        ["ReviewableVoiceUser"],
      )
    end
  end
end
