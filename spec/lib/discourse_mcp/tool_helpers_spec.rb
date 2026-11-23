# frozen_string_literal: true

RSpec.describe DiscourseMcp::ToolHelpers do
  describe ".submit_post!" do
    subject(:submission) { described_class.submit_post!(user, title:, raw:) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    let(:title) { "A topic submitted through the helper" }
    let(:raw) { "A complete topic body for this example." }

    context "when a handler takes the post" do
      before { allow(NewPostManager).to receive(:handlers).and_return([handler]) }

      context "when the handler returns a failed result without errors" do
        let(:handler) { ->(_manager) { NewPostResult.new(:custom) } }

        it "raises a tool error with a default message" do
          expect { submission }.to raise_error(
            DiscourseMcp::ToolError,
            I18n.t("mcp.errors.post_not_created"),
          )
        end
      end

      context "when the handler returns a successful result without a post" do
        let(:handler) { ->(_manager) { NewPostResult.new(:custom, true) } }

        it "raises a tool error with a default message" do
          expect { submission }.to raise_error(
            DiscourseMcp::ToolError,
            I18n.t("mcp.errors.post_not_created"),
          )
        end
      end

      context "when the handler queues the post" do
        let(:handler) { ->(manager) { manager.enqueue(:custom) } }

        it "returns the queued submission" do
          expect(submission).to have_attributes(action: :enqueued, post: nil)
        end
      end
    end

    context "when no handler takes the post" do
      it "returns the published post" do
        expect(submission.post).to have_attributes(user:, raw:)
      end
    end
  end
end
