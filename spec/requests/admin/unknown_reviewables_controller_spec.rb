# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UnknownReviewablesController do
  let(:admin) { Fabricate(:admin) }
  let(:user) { Fabricate(:user) }
  fab!(:reviewable)
  fab!(:unknown_reviewable) { Fabricate(:reviewable, type: "ReviewablePost") }

  describe "#destroy" do
    context "when user is an admin" do
      before do
        sign_in admin

        allow(Reviewable).to receive(:types).and_return([ReviewableUser])
      end

      it "destroys all pending reviewables of specified types" do
        delete "/admin/unknown_reviewables/destroy.json"
        expect(response.code).to eq("200")

        reviewable.reload
        expect { unknown_reviewable.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when user is not an admin" do
      before { sign_in user }

      it "raises Discourse::InvalidAccess" do
        delete "/admin/unknown_reviewables/destroy.json"
        expect(response.code).to eq("404")
      end
    end
  end
end
