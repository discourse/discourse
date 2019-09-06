# frozen_string_literal: true

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

    it "does not show staff-only tags" do
      tag_group = Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: ["test"])

      get "/tags/test"
      expect(response.status).to eq(404)

      sign_in(Fabricate(:admin))

      get "/tags/test"
      expect(response.status).to eq(200)
    end
  end

  describe '#check_hashtag' do
    fab!(:tag) { Fabricate(:tag, name: 'test') }

    it "should return the right response" do
      get "/tags/check.json", params: { tag_values: [tag.name] }

      expect(response.status).to eq(200)

      tag = JSON.parse(response.body)["valid"].first
      expect(tag["value"]).to eq('test')
    end
  end

  describe "#update" do
    fab!(:tag) { Fabricate(:tag) }
    fab!(:admin) { Fabricate(:admin) }

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
    fab!(:regular_user) { Fabricate(:trust_level_4) }
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:admin) { Fabricate(:admin) }
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
    fab!(:tag)       { Fabricate(:tag) }
    fab!(:other_tag) { Fabricate(:tag) }
    fab!(:third_tag) { Fabricate(:tag) }
    fab!(:category)  { Fabricate(:category) }
    fab!(:subcategory) { Fabricate(:category, parent_category_id: category.id) }

    fab!(:single_tag_topic) { Fabricate(:topic, tags: [tag]) }
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
      def parse_topic_ids
        JSON.parse(response.body)["topic_list"]["topics"]
          .map { |topic| topic["id"] }
      end

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

        topic_ids = parse_topic_ids
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

        topic_ids = parse_topic_ids
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

        topic_ids = parse_topic_ids
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

        topic_ids = parse_topic_ids
        expect(topic_ids).to include(t.id)
      end

      context "when logged in" do
        fab!(:user) { Fabricate(:user) }

        before do
          sign_in(user)
        end

        it "can filter by bookmarked" do
          get "/tags/#{tag.name}/l/bookmarks.json"

          expect(response.status).to eq(200)
        end

        context "muted tags" do
          before do
            TagUser.create!(
              user_id: user.id,
              tag_id: tag.id,
              notification_level: CategoryUser.notification_levels[:muted]
            )
          end

          it "includes topics when filtered by muted tag" do
            single_tag_topic

            get "/tags/#{tag.name}/l/latest.json"
            expect(response.status).to eq(200)

            topic_ids = parse_topic_ids
            expect(topic_ids).to include(single_tag_topic.id)
          end

          it "includes topics when filtered by category and muted tag" do
            category = Fabricate(:category)
            single_tag_topic.update!(category: category)

            get "/tags/c/#{category.slug}/#{tag.name}/l/latest.json"
            expect(response.status).to eq(200)

            topic_ids = parse_topic_ids
            expect(topic_ids).to include(single_tag_topic.id)
          end
        end
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

      it "returns tags ordered by topic_count, and prioritises exact matches" do
        Fabricate(:tag, name: 'tag1', topic_count: 10)
        Fabricate(:tag, name: 'tag2', topic_count: 100)
        Fabricate(:tag, name: 'tag', topic_count: 1)

        get '/tags/filter/search.json', params: { q: 'tag', limit: 2 }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json['results'].map { |j| j['id'] }).to eq(['tag', 'tag2'])
      end

      context 'with category restriction' do
        fab!(:yup) { Fabricate(:tag, name: 'yup') }
        fab!(:category) { Fabricate(:category, tags: [yup]) }

        it "can say if given tag is not allowed" do
          nope = Fabricate(:tag, name: 'nope')
          get "/tags/filter/search.json", params: { q: nope.name, categoryId: category.id }
          expect(response.status).to eq(200)
          json = ::JSON.parse(response.body)
          expect(json["results"].map { |j| j["id"] }.sort).to eq([])
          expect(json["forbidden"]).to be_present
          expect(json["forbidden_message"]).to eq(I18n.t("tags.forbidden.in_this_category", tag_name: nope.name))
        end

        it "can say if given tag is restricted to different category" do
          category
          get "/tags/filter/search.json", params: { q: yup.name, categoryId: Fabricate(:category).id }
          json = ::JSON.parse(response.body)
          expect(json["results"].map { |j| j["id"] }.sort).to eq([])
          expect(json["forbidden"]).to be_present
          expect(json["forbidden_message"]).to eq(I18n.t(
            "tags.forbidden.restricted_to",
            count: 1,
            tag_name: yup.name,
            category_names: category.name
          ))
        end
      end

      it "matches tags after sanitizing input" do
        yup, nope = Fabricate(:tag, name: 'yup'), Fabricate(:tag, name: 'nope')
        get "/tags/filter/search.json", params: { q: 'N/ope' }
        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        expect(json["results"].map { |j| j["id"] }.sort).to eq(["nope"])
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

  describe '#unused' do
    it "fails if you can't manage tags" do
      sign_in(Fabricate(:user))
      get "/tags/unused.json"
      expect(response.status).to eq(403)
      delete "/tags/unused.json"
      expect(response.status).to eq(403)
    end

    context 'logged in' do
      before do
        sign_in(Fabricate(:admin))
      end

      context 'with some tags' do
        let!(:tags) { [
          Fabricate(:tag, name: "used_publically", topic_count: 2, pm_topic_count: 0),
          Fabricate(:tag, name: "used_privately", topic_count: 0, pm_topic_count: 3),
          Fabricate(:tag, name: "used_everywhere", topic_count: 0, pm_topic_count: 3),
          Fabricate(:tag, name: "unused1", topic_count: 0, pm_topic_count: 0),
          Fabricate(:tag, name: "unused2", topic_count: 0, pm_topic_count: 0)
        ]}

        it 'returns the correct unused tags' do
          get "/tags/unused.json"
          expect(response.status).to eq(200)
          json = ::JSON.parse(response.body)
          expect(json["tags"]).to contain_exactly("unused1", "unused2")
        end

        it 'deletes the correct tags' do
          expect { delete "/tags/unused.json" }.to change { Tag.count }.by(-2) & change { UserHistory.count }.by(1)
          expect(Tag.pluck(:name)).to contain_exactly("used_publically", "used_privately", "used_everywhere")
        end
      end

    end
  end

  context '#upload_csv' do
    it 'requires you to be logged in' do
      post "/tags/upload.json"
      expect(response.status).to eq(403)
    end

    context 'while logged in' do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/tags.csv") }
      let(:invalid_csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/tags_invalid.csv") }

      let(:file) do
        Rack::Test::UploadedFile.new(File.open(csv_file))
      end

      let(:invalid_file) do
        Rack::Test::UploadedFile.new(File.open(invalid_csv_file))
      end

      let(:filename) { 'tags.csv' }

      it "fails if you can't manage tags" do
        sign_in(Fabricate(:user))
        post "/tags/upload.json", params: { file: file, name: filename }
        expect(response.status).to eq(403)
      end

      it "allows staff to bulk upload tags" do
        sign_in(Fabricate(:moderator))
        post "/tags/upload.json", params: { file: file, name: filename }
        expect(response.status).to eq(200)
        expect(Tag.pluck(:name)).to contain_exactly("tag1", "capitaltag2", "spaced-tag", "tag3", "tag4")
        expect(Tag.find_by_name("tag3").tag_groups.pluck(:name)).to contain_exactly("taggroup1")
        expect(Tag.find_by_name("tag4").tag_groups.pluck(:name)).to contain_exactly("taggroup1")
      end

      it "fails gracefully with invalid input" do
        sign_in(Fabricate(:moderator))

        expect do
          post "/tags/upload.json", params: { file: invalid_file, name: filename }
          expect(response.status).to eq(422)
        end.not_to change { [Tag.count, TagGroup.count] }
      end
    end
  end
end
