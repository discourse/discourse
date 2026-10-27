# frozen_string_literal: true

RSpec.describe Jobs::UnsilenceUsers do
  it "unsilence users" do
    user = Fabricate(:user)
    UserSilencer.silence(user, Discourse.system_user, silenced_till: 2.days.ago)

    user.reload
    expect(user.silenced_till).to be

    Jobs::UnsilenceUsers.new.execute({})

    user.reload
    expect(user.silenced_till).to be(nil)
  end

  context "with an anonymous shadow" do
    fab!(:main, :user)
    fab!(:shadow) do
      Fabricate(:anonymous).tap { it.anonymous_user_master.update!(master_user: main) }
    end

    before { SiteSetting.allow_anonymous_mode = true }

    it "unsilences and reports the account behind the shadow once its silence ends" do
      UserSilencer.silence(shadow, Discourse.system_user, silenced_till: 2.days.ago)

      events = DiscourseEvent.track_events(:user_unsilenced) { described_class.new.execute({}) }

      expect(main.reload.silenced_till).to be_nil
      expect(events.map { it[:params].first[:user] }).to eq([main])
    end

    it "clears the shadow's own expired column without unsilencing the account behind it" do
      main.update!(silenced_till: 1.day.from_now)
      shadow.update_columns(silenced_till: 2.days.ago)

      events = DiscourseEvent.track_events(:user_unsilenced) { described_class.new.execute({}) }

      expect(events).to be_empty
      expect(shadow.reload[:silenced_till]).to be_nil
      expect(main.reload).to be_silenced
    end
  end
end
