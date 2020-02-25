# frozen_string_literal: true

require 'rails_helper'

describe NotificationSerializer do
  describe '#as_json' do
    fab!(:user) { Fabricate(:user) }
    let(:notification) { Fabricate(:notification, user: user) }
    let(:serializer) { NotificationSerializer.new(notification) }
    let(:json) { serializer.as_json }

    it "returns the user_id" do
      expect(json[:notification][:user_id]).to eq(user.id)
    end

  end
end
