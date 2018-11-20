require "rails_helper"

describe Jobs::UnsilenceUsers do
  it "unsilence users" do
    user = Fabricate(:user)
    UserSilencer.silence(user, Discourse.system_user, silenced_till: 2.days.ago)

    user.reload
    expect(user.silenced_till).to be

    Jobs::UnsilenceUsers.new.execute({})

    user.reload
    expect(user.silenced_till).to be(nil)
  end
end
