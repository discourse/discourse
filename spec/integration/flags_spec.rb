# frozen_string_literal: true

RSpec.describe PostAction do
  it "triggers the 'flag_reviewed' event when there was at least one flag" do
    user = Fabricate(:user, trust_level: TrustLevel[4])

    post = Fabricate(:post)
    events = DiscourseEvent.track_events { PostDestroyer.new(user, post).destroy }
    expect(events.map { |e| e[:event_name] }).to_not include(:flag_reviewed)

    flagged_post = Fabricate(:post)
    PostActionCreator.spam(user, flagged_post)
    events = DiscourseEvent.track_events { PostDestroyer.new(user, flagged_post).destroy }
    expect(events.map { |e| e[:event_name] }).to include(:flag_reviewed)
  end
end
