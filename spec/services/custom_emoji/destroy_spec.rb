# frozen_string_literal: true

RSpec.describe CustomEmoji::Destroy do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:actor, :admin)
    fab!(:custom_emoji) { Fabricate(:custom_emoji, name: "party") }

    let(:params) { { name: } }
    let(:dependencies) { { guardian: actor.guardian } }
    let(:name) { "party" }

    context "without a name" do
      let(:name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the custom emoji does not exist" do
      let(:name) { "missing" }

      it { is_expected.to run_successfully }

      it "enqueues a rebake for the requested name" do
        expect_enqueued_with(job: :rebake_custom_emoji_posts, args: { name: }) { result }
      end
    end

    context "when the custom emoji exists" do
      it { is_expected.to run_successfully }

      it "deletes the custom emoji" do
        expect { result }.to change { CustomEmoji.exists?(custom_emoji.id) }.from(true).to(false)
      end

      it "logs the destruction" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:custom_emoji_destroy]).count
        }.by(1)

        expect(UserHistory.last).to have_attributes(acting_user_id: actor.id, previous_value: name)
      end

      it "invalidates the custom emoji cache" do
        expect(Emoji.custom.map(&:name)).to include(name)

        result

        expect(Emoji.custom.map(&:name)).not_to include(name)
      end

      it "enqueues a rebake for the deleted emoji" do
        expect_enqueued_with(job: :rebake_custom_emoji_posts, args: { name: }) { result }
      end
    end
  end
end
