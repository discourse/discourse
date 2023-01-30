# frozen_string_literal: true

RSpec.describe Jobs::UpdateUsername do
  fab!(:user) { Fabricate(:user) }

  it "does not do anything if user_id is invalid" do
    events =
      DiscourseEvent.track_events do
        described_class.new.execute(
          user_id: -999,
          old_username: user.username,
          new_username: "somenewusername",
          avatar_template: user.avatar_template,
        )
      end

    expect(events).to eq([])
  end
end
