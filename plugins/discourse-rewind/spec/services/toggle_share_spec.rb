# frozen_string_literal: true

RSpec.describe(DiscourseRewind::ToggleShare) do
  describe ".call" do
    subject(:result) { described_class.call(**dependencies) }

    fab!(:user)

    let(:guardian) { Guardian.new(user) }
    let(:dependencies) { { guardian: } }

    context "when discourse_rewind_share_publicly is false" do
      before { user.user_option.update!(discourse_rewind_share_publicly: false) }

      it "toggles to true" do
        expect { result }.to change {
          user.user_option.reload.discourse_rewind_share_publicly
        }.from(false).to(true)
      end

      context "when user has hide_profile set to true" do
        before { user.user_option.update!(hide_profile: true) }

        it { is_expected.to fail_a_policy(:user_not_hiding_profile) }
      end
    end

    context "when discourse_rewind_share_publicly is true" do
      before { user.user_option.update!(discourse_rewind_share_publicly: true) }

      it "toggles to false" do
        expect { result }.to change {
          user.user_option.reload.discourse_rewind_share_publicly
        }.from(true).to(false)
      end

      context "when user has hide_profile set to true" do
        before { user.user_option.update!(hide_profile: true) }

        it "toggles to false" do
          expect { result }.to change {
            user.user_option.reload.discourse_rewind_share_publicly
          }.from(true).to(false)
        end
      end
    end
  end
end
