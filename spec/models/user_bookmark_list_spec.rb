# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBookmarkList do
  let(:params) { {} }
  fab!(:user) { Fabricate(:user) }
  let(:list) { UserBookmarkList.new(user: user, guardian: Guardian.new(user), params: params) }

  before do
    22.times do
      bookmark = Fabricate(:bookmark, user: user)
      Fabricate(:topic_user, topic: bookmark.topic, user: user)
    end
  end

  it "defaults to 20 per page" do
    expect(list.per_page).to eq(20)
  end

  context "when the per_page param is too high" do
    let(:params) { { per_page: 1000 } }

    it "does not allow more than X bookmarks to be requested per page" do
      expect(list.load.count).to eq(20)
    end
  end
end
