require 'spec_helper'

describe Admin::BadgesController do
  it "is a subclass of AdminController" do
    (Admin::BadgesController < Admin::AdminController).should be_true
  end

  context "while logged in as an admin" do
    let!(:user) { log_in(:admin) }
    let!(:badge) { Fabricate(:badge) }

    context '.badge_types' do
      it 'returns success' do
        xhr :get, :badge_types
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :badge_types
        ::JSON.parse(response.body)["badge_types"].should be_present
      end
    end

    context '.destroy' do
      it 'returns success' do
        xhr :delete, :destroy, id: badge.id
        response.should be_success
      end

      it 'deletes the badge' do
        xhr :delete, :destroy, id: badge.id
        Badge.where(id: badge.id).count.should eq(0)
      end
    end

    context '.update' do
      it 'returns success' do
        xhr :put, :update, id: badge.id, name: "123456", badge_type_id: badge.badge_type_id, allow_title: false, multiple_grant: false
        response.should be_success
      end

      it 'updates the badge' do
        xhr :put, :update, id: badge.id, name: "123456", badge_type_id: badge.badge_type_id, allow_title: false, multiple_grant: true
        badge.reload.name.should eq('123456')
      end
    end
  end
end
