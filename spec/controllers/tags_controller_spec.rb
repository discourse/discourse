require 'rails_helper'

describe TagsController do
  describe 'show_latest' do
    let(:tag)         { Fabricate(:tag) }
    let(:category)    { Fabricate(:category) }
    let(:subcategory) { Fabricate(:category, parent_category_id: category.id) }

    context 'tagging disabled' do
      it "returns 404" do
        xhr :get, :show_latest, tag_id: tag.name
        expect(response.status).to eq(404)
      end
    end

    context 'tagging enabled' do
      before do
        SiteSetting.tagging_enabled = true
      end

      it "can filter by tag" do
        xhr :get, :show_latest, tag_id: tag.name
        expect(response).to be_success
      end

      it "can filter by category and tag" do
        xhr :get, :show_latest, tag_id: tag.name, category: category.slug
        expect(response).to be_success
      end

      it "can filter by category, sub-category, and tag" do
        xhr :get, :show_latest, tag_id: tag.name, category: subcategory.slug, parent_category: category.slug
        expect(response).to be_success
      end

      it "can filter by category, no sub-category, and tag" do
        xhr :get, :show_latest, tag_id: tag.name, category: 'none', parent_category: category.slug
        expect(response).to be_success
      end
    end
  end
end
