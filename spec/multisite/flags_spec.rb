# frozen_string_literal: true

RSpec.describe "Custom flags in multisite", type: :multisite do
  describe "PostACtionType#all_flags" do
    it "does not share flag definitions between sites" do
      flag_1 = Flag.create!(name: "test flag 1", position: 99, applies_to: ["Post"])
      expect(ReviewableScore.types).to eq(
        {
          notify_user: 6,
          off_topic: 3,
          inappropriate: 4,
          spam: 8,
          illegal: 10,
          notify_moderators: 7,
          custom_test_flag_1: flag_1.id,
          needs_approval: 9,
        },
      )

      test_multisite_connection("second") do
        flag_2 = Flag.create!(name: "test flag 2", position: 99, applies_to: ["Post"])
        PostActionType.new.expire_cache
        expect(PostActionType.all_flags.last).to eq(
          flag_2.attributes.except("created_at", "updated_at").transform_keys(&:to_sym),
        )
        expect(ReviewableScore.types).to eq(
          {
            notify_user: 6,
            off_topic: 3,
            inappropriate: 4,
            spam: 8,
            illegal: 10,
            notify_moderators: 7,
            custom_test_flag_2: flag_2.id,
            needs_approval: 9,
          },
        )
      end

      PostActionType.new.expire_cache
      expect(PostActionType.all_flags.last).to eq(
        flag_1.attributes.except("created_at", "updated_at").transform_keys(&:to_sym),
      )
      expect(ReviewableScore.types).to eq(
        {
          notify_user: 6,
          off_topic: 3,
          inappropriate: 4,
          spam: 8,
          illegal: 10,
          notify_moderators: 7,
          custom_test_flag_1: flag_1.id,
          needs_approval: 9,
        },
      )
    end
  end
end
