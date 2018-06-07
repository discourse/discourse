require 'rails_helper'

describe TagsController do
  before do
    SiteSetting.tagging_enabled = true
  end

  describe '#index' do

    before do
      Fabricate(:tag, name: 'test')
      Fabricate(:tag, name: 'topic-test', topic_count: 1)
    end

    shared_examples "successfully retrieve tags with topic_count > 0" do
      it "should return the right response" do
        get "/tags.json"

        expect(response.status).to eq(200)

        tags = JSON.parse(response.body)["tags"]
        expect(tags.length).to eq(1)
        expect(tags[0]['text']).to eq("topic-test")
      end
    end

    context "with tags_listed_by_group enabled" do
      before { SiteSetting.tags_listed_by_group = true }
      include_examples "successfully retrieve tags with topic_count > 0"
    end

    context "with tags_listed_by_group disabled" do
      before { SiteSetting.tags_listed_by_group = false }
      include_examples "successfully retrieve tags with topic_count > 0"
    end

    context "when user can admin tags" do

      it "succesfully retrieve all tags" do
        sign_in(Fabricate(:admin))

        get "/tags.json"

        expect(response.status).to eq(200)

        tags = JSON.parse(response.body)["tags"]
        expect(tags.length).to eq(2)
      end

    end
  end

  describe '#show' do
    before do
      Fabricate(:tag, name: 'test')
    end

    it "should return the right response" do
      get "/tags/test"
      expect(response.status).to eq(200)
    end

    it "should handle invalid tags" do
      get "/tags/%2ftest%2f"
      expect(response.status).to eq(404)
    end
  end

  describe '#check_hashtag' do
    let(:tag) { Fabricate(:tag, name: 'test') }

    it "should return the right response" do
      get "/tags/check.json", params: { tag_values: [tag.name] }

      expect(response.status).to eq(200)

      tag = JSON.parse(response.body)["valid"].first
      expect(tag["value"]).to eq('test')
    end
  end

  describe "#update" do
    let(:tag) { Fabricate(:tag) }
    let(:admin) { Fabricate(:admin) }

    before do
      tag
      sign_in(admin)
    end

    it "triggers a extensibility event" do
      event = DiscourseEvent.track_events {
        put "/tags/#{tag.name}.json", params: {
          tag: {
            id: 'hello'
          }
        }
      }.last

      expect(event[:event_name]).to eq(:tag_updated)
      expect(event[:params].first).to eq(tag)
    end
  end

  describe '#personal_messages' do
    let(:regular_user) { Fabricate(:trust_level_4) }
    let(:moderator) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }
    let(:personal_message) do
      Fabricate(:private_message_topic, user: regular_user, topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: regular_user),
        Fabricate.build(:topic_allowed_user, user: moderator),
        Fabricate.build(:topic_allowed_user, user: admin)
      ])
    end

    before do
      SiteSetting.allow_staff_to_tag_pms = true
      Fabricate(:tag, topics: [personal_message], name: 'test')
    end

    context "as a regular user" do
      it "can't see pm tags" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response).not_to be_successful
      end
    end

    context "as an moderator" do
      before do
        sign_in(moderator)
      end

      it "can't see pm tags for regular user" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response).not_to be_successful
      end

      it "can see their own pm tags" do
        get "/tags/personal_messages/#{moderator.username}.json"

        expect(response.status).to eq(200)

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end
    end

    context "as an admin" do
      before do
        sign_in(admin)
      end

      it "can see pm tags for regular user" do
        get "/tags/personal_messages/#{regular_user.username}.json"

        expect(response.status).to eq(200)

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end

      it "can see their own pm tags" do
        get "/tags/personal_messages/#{admin.username}.json"

        expect(response.status).to eq(200)

        tag = JSON.parse(response.body)['tags']
        expect(tag[0]["id"]).to eq('test')
      end
    end
  end

  describe '#show_latest' do
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
        SiteSetting.tagging_enabled = false
        get "/tags/#{tag.name}/l/latest.json"
        expect(response.status).to eq(404)
      end
    end

    context 'tagging enabled' do
      it "can filter by tag" do
        get "/tags/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can filter by two tags" do
        single_tag_topic; multi_tag_topic; all_tag_topic

        get "/tags/#{tag.name}/l/latest.json", params: {
          additional_tag_ids: other_tag.name
        }

        expect(response.status).to eq(200)

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to include(all_tag_topic.id)
        expect(topic_ids).to include(multi_tag_topic.id)
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "can filter by multiple tags" do
        single_tag_topic; multi_tag_topic; all_tag_topic

        get "/tags/#{tag.name}/l/latest.json", params: {
          additional_tag_ids: "#{other_tag.name}/#{third_tag.name}"
        }

        expect(response.status).to eq(200)

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to include(all_tag_topic.id)
        expect(topic_ids).to_not include(multi_tag_topic.id)
        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "does not find any tags when a tag which doesn't exist is passed" do
        single_tag_topic

        get "/tags/#{tag.name}/l/latest.json", params: {
          additional_tag_ids: "notatag"
        }

        expect(response.status).to eq(200)

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to_not include(single_tag_topic.id)
      end

      it "can filter by category and tag" do
        get "/tags/c/#{category.slug}/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can filter by category, sub-category, and tag" do
        get "/tags/c/#{category.slug}/#{subcategory.slug}/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can filter by category, no sub-category, and tag" do
        get "/tags/c/#{category.slug}/none/#{tag.name}/l/latest.json"
        expect(response.status).to eq(200)
      end

      it "can handle subcategories with the same name" do
        category2 = Fabricate(:category)
        subcategory2 = Fabricate(:category,
          parent_category_id: category2.id,
          name: subcategory.name,
          slug: subcategory.slug
        )
        t = Fabricate(:topic, category_id: subcategory2.id, tags: [other_tag])
        get "/tags/c/#{category2.slug}/#{subcategory2.slug}/#{other_tag.name}/l/latest.json"

        expect(response.status).to eq(200)

        topic_ids = JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }

        expect(topic_ids).to include(t.id)
      end

      it "can filter by bookmarked" do
        sign_in(Fabricate(:user))
        get "/tags/#{tag.name}/l/bookmarks.json"

        expect(response.status).to eq(200)
      end
    end
  end

  describe '#search' do
    context 'tagging disabled' do
      it "returns 404" do
        SiteSetting.tagging_enabled = false
        get "/tags/filter/search.json", params: { q: 'stuff' }
        expect(response.status).to eq(404)
      end
    end

    context 'tagging enabled' do
      it "can return some tags" do
        tag_names = ['stuff', 'stinky', 'stumped']
        tag_names.each { |name| Fabricate(:tag, name: name) }
        get "/tags/filter/search.json", params: { q: 'stu' }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }.sort).to eq(['stuff', 'stumped'])
      end

      it "can say if given tag is not allowed" do
        yup, nope = Fabricate(:tag, name: 'yup'), Fabricate(:tag, name: 'nope')
        category = Fabricate(:category, tags: [yup])
        get "/tags/filter/search.json", params: { q: 'nope', categoryId: category.id }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }.sort).to eq([])
        expect(json["forbidden"]).to be_present
      end

      it "can return tags that are in secured categories but are allowed to be used" do
        c = Fabricate(:private_category, group: Fabricate(:group))
        Fabricate(:topic, category: c, tags: [Fabricate(:tag, name: "cooltag")])
        get "/tags/filter/search.json", params: { q: "cool" }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }).to eq(['cooltag'])
      end

      it "supports Chinese and Russian" do
        tag_names = ['房地产', 'тема-в-разработке']
        tag_names.each { |name| Fabricate(:tag, name: name) }

        get "/tags/filter/search.json", params: { q: '房' }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }).to eq(['房地产'])

        get "/tags/filter/search.json", params: { q: 'тема' }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }).to eq(['тема-в-разработке'])
      end
    end
  end

  describe '#destroy' do
    context 'tagging enabled' do
      before do
        sign_in(Fabricate(:admin))
      end

      context 'with an existent tag name' do
        it 'deletes the tag' do
          tag = Fabricate(:tag)
          delete "/tags/#{tag.name}.json"
          expect(response.status).to eq(200)
          expect(Tag.where(id: tag.id)).to be_empty
        end
      end

      context 'with a nonexistent tag name' do
        it 'returns a tag not found message' do
          delete "/tags/doesntexists.json"
          expect(response).not_to be_successful
          json = ::JSON.parse(response.body)
          expect(json['error_type']).to eq('not_found')
        end
      end
    end
  end
end
