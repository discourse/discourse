# frozen_string_literal: true

RSpec.describe CustomEmoji::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:file) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:actor, :admin)

    let(:params) { { file:, name: "PaRTY.png", group: "Foo" } }
    let(:dependencies) { { guardian: actor.guardian } }
    let(:file) do
      Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/images/logo.png"), "image/png")
    end

    context "without an uploaded file" do
      let(:file) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "with files instead of a file" do
      let(:params) { { files: [file], name: "party" } }

      it { is_expected.to run_successfully }
    end

    context "when the upload is invalid" do
      let(:file) do
        Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/images/fake.jpg"), "image/jpeg")
      end

      it { is_expected.to fail_with_an_invalid_model(:upload) }
    end

    context "when the emoji is invalid" do
      fab!(:existing_emoji) { Fabricate(:custom_emoji, name: "party") }

      it { is_expected.to fail_with_an_invalid_model(:custom_emoji) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a normalized custom emoji owned by the actor" do
        expect(result.custom_emoji).to have_attributes(name: "party", group: "foo", user: actor)
        expect(result.custom_emoji.upload.original_filename).to eq("logo.png")
      end

      it "logs the creation" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:custom_emoji_create]).count
        }.by(1)

        expect(UserHistory.last).to have_attributes(acting_user_id: actor.id, new_value: "party")
      end

      it "invalidates the custom emoji cache" do
        expect(Emoji.custom.map(&:name)).not_to include("party")

        result

        expect(Emoji.custom.map(&:name)).to include("party")
      end
    end
  end
end
