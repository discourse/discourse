# frozen_string_literal: true

describe PostLocalizationSerializer do
  fab!(:post_localization)

  describe "serialized attributes" do
    it "disaplays every attribute" do
      serialized = described_class.new(post_localization, scope: Guardian.new, root: false)

      expect(serialized).to have_attributes(
        id: post_localization.id,
        post_id: post_localization.post_id,
        locale: post_localization.locale,
        raw: post_localization.raw,
      )
    end
  end
end
