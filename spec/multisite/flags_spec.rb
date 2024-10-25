# frozen_string_literal: true

RSpec.describe "Custom flags in multisite", type: :multisite do
  describe "PostACtionType#all_flags" do
    it "does not share flag definitions between sites" do
      flag_1 = Flag.create!(name: "test flag 1", position: 99, applies_to: ["Post"])

      test_multisite_connection("second") do
        flag_2 = Flag.create!(name: "test flag 2", position: 99, applies_to: ["Post"])
        PostActionType.new.expire_cache
        expect(PostActionType.all_flags.last).to eq(
          flag_2.attributes.except("created_at", "updated_at").transform_keys(&:to_sym),
        )
      end

      PostActionType.new.expire_cache
      expect(PostActionType.all_flags.last).to eq(
        flag_1.attributes.except("created_at", "updated_at").transform_keys(&:to_sym),
      )
    end
  end
end
