# frozen_string_literal: true

RSpec.describe WebArtifactKeyValue do
  fab!(:user)
  fab!(:web_artifact)

  describe "#validate_max_keys_per_user_per_artifact" do
    before { SiteSetting.web_artifact_max_keys_per_user_per_artifact = 2 }

    it "prevents creation when at the limit" do
      2.times do |i|
        described_class.create!(
          web_artifact: web_artifact,
          user: user,
          key: "key_#{i}",
          value: "val",
        )
      end

      record =
        described_class.new(web_artifact: web_artifact, user: user, key: "key_extra", value: "val")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include(
        I18n.t("web_artifact.errors.max_keys_exceeded", count: 2),
      )
    end

    it "allows different users to have their own keys" do
      2.times do |i|
        described_class.create!(
          web_artifact: web_artifact,
          user: user,
          key: "key_#{i}",
          value: "val",
        )
      end

      other_user = Fabricate(:user)
      record =
        described_class.new(
          web_artifact: web_artifact,
          user: other_user,
          key: "key_0",
          value: "val",
        )
      expect(record).to be_valid
    end
  end

  describe "validations" do
    it "enforces value max length" do
      SiteSetting.web_artifact_kv_value_max_length = 10
      record =
        described_class.new(web_artifact: web_artifact, user: user, key: "test", value: "a" * 11)
      expect(record).not_to be_valid
    end

    it "enforces key uniqueness per user per artifact" do
      described_class.create!(
        web_artifact: web_artifact,
        user: user,
        key: "unique_key",
        value: "val1",
      )
      record =
        described_class.new(
          web_artifact: web_artifact,
          user: user,
          key: "unique_key",
          value: "val2",
        )
      expect(record).not_to be_valid
    end
  end
end
