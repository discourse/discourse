require 'rails_helper'

describe CategoryHashtagsController do
  describe "check" do
    describe "logged in" do
      before do
        log_in(:user)
      end

      it 'only returns the categories that are valid' do
        category = Fabricate(:category)

        get :check, params: { category_slugs: [category.slug, 'none'] }, format: :json

        expect(JSON.parse(response.body)).to eq(
          "valid" => [{ "slug" => category.hashtag_slug, "url" => category.url_with_id }]
        )
      end

      it 'does not return restricted categories for a normal user' do
        group = Fabricate(:group)
        private_category = Fabricate(:private_category, group: group)

        get :check, params: { category_slugs: [private_category.slug] }, format: :json

        expect(JSON.parse(response.body)).to eq("valid" => [])
      end

      it 'returns restricted categories for an admin' do
        admin = log_in(:admin)
        group = Fabricate(:group)
        group.add(admin)
        private_category = Fabricate(:private_category, group: group)

        get :check,
          params: { category_slugs: [private_category.slug] },
          format: :json

        expect(JSON.parse(response.body)).to eq(
          "valid" => [{ "slug" => private_category.hashtag_slug, "url" => private_category.url_with_id }]
        )
      end
    end

    describe "not logged in" do
      it 'raises an exception' do
        expect do
          get :check, params: { category_slugs: [] }, format: :json
        end.to raise_error(Discourse::NotLoggedIn)
      end
    end
  end
end
