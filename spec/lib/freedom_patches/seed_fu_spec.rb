# frozen_string_literal: true

RSpec.describe "seed-fu patch" do
  it "does not modify a sequence on an existing table" do
    u = User.create!(username: "test1", email: "test1@example.com")
    uid1 = u.id
    UserDestroyer.new(Discourse.system_user).destroy(u)

    SeedFu.quiet = true
    SeedFu.seed

    # Ensure sequence was not reset. A new user should have
    # id one greater than the last user
    u2 = User.create!(username: "test1", email: "test1@example.com")
    expect(u2.id).to eq(uid1 + 1)
  end
end
