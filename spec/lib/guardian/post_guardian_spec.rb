# frozen_string_literal: true

RSpec.describe PostGuardian do
  fab!(:user) { Fabricate(:user) }
  fab!(:anon) { Fabricate(:anonymous) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:tl3_user) { Fabricate(:trust_level_3) }
  fab!(:tl4_user) { Fabricate(:trust_level_4) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:hidden_post) { Fabricate(:post, topic: topic, hidden: true) }

  describe "#can_see_hidden_post?" do
    it "returns true for admin users" do
      expect(Guardian.new(admin).can_see_hidden_post?(hidden_post)).to eq(true)
    end
  end
end
