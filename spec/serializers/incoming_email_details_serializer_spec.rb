# frozen_string_literal: true

RSpec.describe IncomingEmailDetailsSerializer do
  fab!(:admin)
  fab!(:rejected_incoming_email)
  fab!(:incoming_email)

  describe "#error" do
    it "includes the error attribute when the incoming email is errored" do
      serialized =
        described_class.new(
          rejected_incoming_email,
          scope: Guardian.new(admin),
          root: false,
        ).as_json

      expect(serialized[:error]).to eq(rejected_incoming_email.error)
    end

    it "does not include the error attribute when the incoming email is not errored" do
      serialized =
        described_class.new(incoming_email, scope: Guardian.new(admin), root: false).as_json

      expect(serialized[:error]).to be_nil
    end
  end

  describe "#error_description" do
    it "does not include the error_description attribute when the incoming email is not errored" do
      serialized =
        described_class.new(incoming_email, scope: Guardian.new(admin), root: false).as_json

      expect(serialized[:error_description]).to be_nil
    end

    it "includes the error_description attribute when the incoming email is errored with a known error" do
      serialized =
        described_class.new(
          rejected_incoming_email,
          scope: Guardian.new(admin),
          root: false,
        ).as_json

      expect(serialized[:error_description]).to eq(
        I18n.t("emails.incoming.errors.bad_destination_address"),
      )
    end
  end
end
