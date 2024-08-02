# frozen_string_literal: true

RSpec.describe "Custom flags in multisite", type: :multisite do
  describe "#all_flags" do
    it "does not share flag definitions between sites" do
      flag_1 = Flag.create!(name: "test flag 1", position: 99, applies_to: ["Post"])
      flag_2 = nil

      test_multisite_connection("second") do
        flag_2 = Flag.create!(name: "test flag 2", position: 99, applies_to: ["Post"])
        PostActionType.clear_cache!
        expect(PostActionType.all_flags.last).to eq(flag_2)
      end

      PostActionType.clear_cache!
      expect(PostActionType.all_flags.last).to eq(flag_1)
    end
  end
end
