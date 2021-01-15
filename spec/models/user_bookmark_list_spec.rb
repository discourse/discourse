# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserBookmarkList do
  let(:params) { {} }
  fab!(:user) { Fabricate(:user) }
  let(:list) { UserBookmarkList.new(user: user, guardian: Guardian.new(user), params: params) }

  fab!(:bookmark1) { Fabricate(:bookmark, user: user) }
  fab!(:bookmark2) { Fabricate(:bookmark, user: user) }
  fab!(:bookmark3) { Fabricate(:bookmark, user: user) }

  it "defaults to 20 per page" do
    expect(list.per_page).to eq(20)
  end

  context "when the per_page param is too high" do
    let(:params) { { per_page: 1000 } }

    it "does not allow more than X bookmarks to be requested per page" do
      old_constant = UserBookmarkList::PER_PAGE
      UserBookmarkList.send(:remove_const, "PER_PAGE")
      UserBookmarkList.const_set("PER_PAGE", 1)

      expect(list.load.count).to eq(1)

      UserBookmarkList.send(:remove_const, "PER_PAGE")
      UserBookmarkList.const_set("PER_PAGE", old_constant)
    end
  end
end
