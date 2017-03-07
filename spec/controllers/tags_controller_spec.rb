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

      it "can filter by two tags" do
        single_tag_topic; multi_tag_topic; all_tag_topic
        xhr :get, :show_latest, tag_id: tag.name, additional_tag_ids: other_tag.name
        expect(response).to be_success
        expect(assigns(:list).topics).to include all_tag_topic
        expect(assigns(:list).topics).to include multi_tag_topic
        expect(assigns(:list).topics).to_not include single_tag_topic
      end

      it "can filter by multiple tags" do
        single_tag_topic; multi_tag_topic; all_tag_topic
        xhr :get, :show_latest, tag_id: tag.name, additional_tag_ids: "#{other_tag.name}/#{third_tag.name}"
        expect(response).to be_success
        expect(assigns(:list).topics).to include all_tag_topic
        expect(assigns(:list).topics).to_not include multi_tag_topic
        expect(assigns(:list).topics).to_not include single_tag_topic
      end

      it "does not find any tags when a tag which doesn't exist is passed" do
        single_tag_topic
        xhr :get, :show_latest, tag_id: tag.name, additional_tag_ids: "notatag"
        expect(response).to be_success
        expect(assigns(:list).topics).to_not include single_tag_topic
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

      it "can handle subcategories with the same name" do
        category2 = Fabricate(:category)
        subcategory2 = Fabricate(:category,
          parent_category_id: category2.id,
          name: subcategory.name,
          slug: subcategory.slug
        )
        t = Fabricate(:topic, category_id: subcategory2.id, tags: [other_tag])
        xhr :get, :show_latest, tag_id: other_tag.name, category: subcategory2.slug, parent_category: category2.slug
        expect(response).to be_success
        expect(assigns(:list).topics).to include(t)
      end

      it "can filter by bookmarked" do
        log_in(:user)
        xhr :get, :show_bookmarks, tag_id: tag.name
        expect(response).to be_success
      end
    end
  end

  describe 'search' do
    context 'tagging disabled' do
      it "returns 404" do
        xhr :get, :search, q: 'stuff'
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
        xhr :get, :search, q: 'stu'
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map{|j| j["id"]}.sort).to eq(['stuff', 'stumped'])
      end

      it "can say if given tag is not allowed" do
        yup, nope = Fabricate(:tag, name: 'yup'), Fabricate(:tag, name: 'nope')
        category = Fabricate(:category, tags: [yup])
        xhr :get, :search, q: 'nope', categoryId: category.id
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map{|j| j["id"]}.sort).to eq([])
        expect(json["forbidden"]).to be_present
      end

      it "can return tags that are in secured categories but are allowed to be used" do
        c = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:topic, category: c, tags: [Fabricate(:tag, name: "cooltag")])
        xhr :get, :search, q: "cool"
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json["results"].map{|j| j["id"]}).to eq(['cooltag'])
      end
    end
  end
end
