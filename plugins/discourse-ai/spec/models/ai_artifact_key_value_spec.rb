# frozen_string_literal: true

RSpec.describe AiArtifactKeyValue, type: :model do
  fab!(:user)
  fab!(:ai_artifact)

  before { enable_current_plugin }

  describe "#validate_max_keys_per_user_per_artifact" do
    before { SiteSetting.ai_artifact_max_keys_per_user_per_artifact = 2 }

    it "prevents creation when at the limit" do
      2.times do |i|
        described_class.create!(
          ai_artifact: ai_artifact,
          user: user,
          key: "key_#{i}",
          value: "value_#{i}",
        )
      end

      new_record =
        described_class.new(
          ai_artifact: ai_artifact,
          user: user,
          key: "new_key",
          value: "new_value",
        )
      expect(new_record).not_to be_valid
      expect(new_record.errors[:base]).to include(
        I18n.t("discourse_ai.ai_artifact.errors.max_keys_exceeded", count: 2),
      )
    end
  end
end
