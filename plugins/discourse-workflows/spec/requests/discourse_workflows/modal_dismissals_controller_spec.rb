# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ModalDismissalsController do
  fab!(:user)

  let(:modal_id) { "abcd1234abcd1234" }

  describe "POST /discourse-workflows/modal-dismissals" do
    it "requires authentication" do
      post "/discourse-workflows/modal-dismissals.json", params: { modal_id: }

      expect(response).to have_http_status(:forbidden)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "returns 204 and closes the user's copies of the modal" do
        messages =
          MessageBus.track_publish(DiscourseWorkflows::Nodes::Modal::V1.user_channel(user.id)) do
            post "/discourse-workflows/modal-dismissals.json", params: { modal_id: }
          end

        expect(response).to have_http_status(:no_content)
        expect(messages.size).to eq(1)
      end

      it "returns 400 for a blank modal id" do
        post "/discourse-workflows/modal-dismissals.json", params: { modal_id: "" }

        expect(response).to have_http_status(:bad_request)
      end

      it "is rate limited" do
        RateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        post "/discourse-workflows/modal-dismissals.json", params: { modal_id: }

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
