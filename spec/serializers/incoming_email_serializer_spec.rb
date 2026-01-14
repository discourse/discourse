# frozen_string_literal: true

RSpec.describe IncomingEmailSerializer do
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
end
