require 'rails_helper'

describe TagsController do
  describe 'show_latest' do
    let(:tag)         { Fabricate(:tag) }
    let(:other_tag)   { Fabricate(:tag) }
    let(:third_tag)   { Fabricate(:tag) }
    let(:category)    { Fabricate(:category) }
    let(:subcategory) { Fabricate(:category, parent_category_id: category.id) }

    let(:single_tag_topic) { Fabricate(:topic, tags: [tag]) }
    let(:multi_tag_topic)  { Fabricate(:topic, tags: [tag, other_tag]) }
    let(:all_tag_topic)    { Fabricate(:topic, tags: [tag, other_tag, third_tag]) }

    context 'tagging disabled' do
      it "returns 404" do
        get :show_latest, params: { tag_id: tag.name }, format: :json
        expect(response.status).to eq(404)
      end
    end

    context 'tagging enabled' do
      before do
        SiteSetting.tagging_enabled = true
      end

      it "can filter by tag" do
        get :show_latest, params: { tag_id: tag.name }, format: :json
        expect(response).to be_success
      end

      it "can filter by two tags" do
        single_tag_topic; multi_tag_topic; all_tag_topic

        get :show_latest, params: {
          tag_id: tag.name, additional_tag_ids: other_tag.name
        }, format: :json

        expect(response).to be_success

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to include(all_tag_topic.id)
        expect(topic_ids).to include(multi_tag_topic.id)
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "can filter by multiple tags" do
        single_tag_topic; multi_tag_topic; all_tag_topic

        get :show_latest, params: {
          tag_id: tag.name, additional_tag_ids: "#{other_tag.name}/#{third_tag.name}"
        }, format: :json

        expect(response).to be_success

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to include(all_tag_topic.id)
        expect(topic_ids).to_not include(multi_tag_topic.id)
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "does not find any tags when a tag which doesn't exist is passed" do
        single_tag_topic

        get :show_latest, params: {
          tag_id: tag.name, additional_tag_ids: "notatag"
        }, format: :json

        expect(response).to be_success

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "can filter by category and tag" do
        get :show_latest, params: {
          tag_id: tag.name, category: category.slug
        }, format: :json

        expect(response).to be_success
      end

      it "can filter by category, sub-category, and tag" do
        get :show_latest, params: {
          tag_id: tag.name, category: subcategory.slug, parent_category: category.slug
        }, format: :json

        expect(response).to be_success
      end

      it "can filter by category, no sub-category, and tag" do
        get :show_latest, params: {
          tag_id: tag.name, category: 'none', parent_category: category.slug
        }, format: :json

        expect(response).to be_success
      end

      it "can handle subcategories with the same name" do
        category2 = Fabricate(:category)
        subcategory2 = Fabricate(:category,
          parent_category_id: category2.id,
          name: subcategory.name,
          slug: subcategory.slug
        )
        t = Fabricate(:topic, category_id: subcategory2.id, tags: [other_tag])
        get :show_latest, params: {
          tag_id: other_tag.name, category: subcategory2.slug, parent_category: category2.slug
        }, format: :json

        expect(response).to be_success

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to include(t.id)
      end

      it "can filter by bookmarked" do
        log_in(:user)
        get :show_bookmarks, params: {
          tag_id: tag.name
        }, format: :json

        expect(response).to be_success
      end
    end
  end

  describe 'search' do
    context 'tagging disabled' do
      it "returns 404" do
        get :search, params: { q: 'stuff' }, format: :json
        expect(response.status).to eq(404)
      end
    end

    context 'tagging enabled' do
      before do
        SiteSetting.tagging_enabled = true
      end

      it "can return some tags" do
        tag_names = ['stuff', 'stinky', 'stumped']
        tag_names.each { |name| Fabricate(:tag, name: name) }
        get :search, params: { q: 'stu' }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }.sort).to eq(['stuff', 'stumped'])
      end

      it "can say if given tag is not allowed" do
        yup, nope = Fabricate(:tag, name: 'yup'), Fabricate(:tag, name: 'nope')
        category = Fabricate(:category, tags: [yup])
        get :search, params: { q: 'nope', categoryId: category.id }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }.sort).to eq([])
        expect(json["forbidden"]).to be_present
      end

      it "can return tags that are in secured categories but are allowed to be used" do
        c = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:topic, category: c, tags: [Fabricate(:tag, name: "cooltag")])
        get :search, params: { q: "cool" }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }).to eq(['cooltag'])
      end

      it "supports Chinese and Russian" do
        tag_names = ['房地产', 'тема-в-разработке']
        tag_names.each { |name| Fabricate(:tag, name: name) }

        get :search, params: { q: '房' }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }).to eq(['房地产'])

        get :search, params: { q: 'тема' }, format: :json
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }).to eq(['тема-в-разработке'])
      end
    end
  end

  describe 'destroy' do
    context 'tagging enabled' do
      before do
        log_in(:admin)
        SiteSetting.tagging_enabled = true
      end

      context 'with an existent tag name' do
        it 'deletes the tag' do
          tag = Fabricate(:tag)
          delete :destroy, params: { tag_id: tag.name }, format: :json
          expect(response).to be_success
        end
      end

      context 'with a nonexistent tag name' do
        it 'returns a tag not found message' do
          delete :destroy, params: { tag_id: 'idontexist' }, format: :json
          expect(response).not_to be_success
          json = ::JSON.parse(response.body)
          expect(json['error_type']).to eq('not_found')
        end
      end
    end
  end
end
