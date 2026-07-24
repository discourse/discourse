# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential do
  describe "validations" do
    describe "data schema validation" do
      it "is valid when all required fields are present" do
        credential =
          described_class.new(
            name: "Auth",
            credential_type: "basic_auth",
            data: {
              "user" => "admin",
              "password" => "secret",
            },
          )

        expect(credential).to be_valid
      end

      it "is invalid when a required field is missing" do
        credential =
          described_class.new(
            name: "Auth",
            credential_type: "basic_auth",
            data: {
              "user" => "admin",
            },
          )

        expect(credential).not_to be_valid
        expect(credential.errors[:data]).to include(
          I18n.t("discourse_workflows.errors.credential.missing_required_field", field: "password"),
        )
      end

      it "is invalid when a required field is empty" do
        credential =
          described_class.new(
            name: "Auth",
            credential_type: "basic_auth",
            data: {
              "user" => "admin",
              "password" => "",
            },
          )

        expect(credential).not_to be_valid
        expect(credential.errors[:data]).to include(
          I18n.t("discourse_workflows.errors.credential.missing_required_field", field: "password"),
        )
      end

      it "skips schema validation when credential_type is unregistered" do
        credential =
          described_class.new(
            name: "Auth",
            credential_type: "unknown_type",
            data: {
              "anything" => "goes",
            },
          )

        expect(credential).to be_valid
      end
    end
  end

  describe "#merge_data" do
    fab!(:credential, :discourse_workflows_credential)

    it "preserves redacted values from original data" do
      credential.merge_data(
        "user" => DiscourseWorkflows::Credential::REDACTED_VALUE,
        "password" => "new_secret",
      )

      expect(credential.data).to eq("user" => "admin", "password" => "new_secret")
    end

    it "adds new keys while preserving originals" do
      credential.merge_data("extra" => "value")

      expect(credential.data).to eq("user" => "admin", "password" => "secret", "extra" => "value")
    end
  end
end
