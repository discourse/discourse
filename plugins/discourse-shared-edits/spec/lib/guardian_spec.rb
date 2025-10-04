# frozen_string_literal: true

RSpec.describe Guardian do
  fab!(:moderator)
  fab!(:user)

  it "disallows shared edits from anon" do
    expect(Guardian.new.can_toggle_shared_edits?).to eq(false)
  end

  it "disallows shared edits for tl3 users" do
    user.trust_level = 3
    expect(Guardian.new(user).can_toggle_shared_edits?).to eq(false)
  end

  it "allows shared edits for staff" do
    expect(Guardian.new(moderator).can_toggle_shared_edits?).to eq(true)
  end

  it "allows shared edits for tl4" do
    user.trust_level = 4
    expect(Guardian.new(user).can_toggle_shared_edits?).to eq(true)
  end
end
