# frozen_string_literal: true

require 'rails_helper'

describe Search do

  context "#prepare_data" do
    it "does not remove English stop words in mixed mode" do
      SiteSetting.search_tokenize_chinese_japanese_korean = true

      tokenized = Search.prepare_data("monkey 吃香蕉 in a loud volume")
      expect(tokenized).to eq("monkey 吃 香蕉 in a loud volume")

      SiteSetting.default_locale = 'zh_CN'

      tokenized = Search.prepare_data("monkey 吃香蕉 in a loud volume")
      expect(tokenized).to eq("monkey 吃 香蕉 loud")
    end
  end

  context "#ts_config" do
    it "maps locales to correct Postgres dictionaries" do
      expect(Search.ts_config).to eq("english")
      expect(Search.ts_config("en")).to eq("english")
      expect(Search.ts_config("en_GB")).to eq("english")
      expect(Search.ts_config("pt_BR")).to eq("portuguese")
      expect(Search.ts_config("tr")).to eq("turkish")
      expect(Search.ts_config("xx")).to eq("simple")
    end
  end

  context "#GroupedSearchResults.blurb_for" do
    it "strips audio and video URLs from search blurb" do
      cooked = <<~RAW
        link to an external page: https://google.com/?u=bar

        link to an audio file: https://somesite.com/content/file123.m4a

        link to a video file: https://somesite.com/content/somethingelse.MOV
      RAW
      result = Search::GroupedSearchResults.blurb_for(cooked: cooked)
      expect(result).to eq("link to an external page: https://google.com/?u=bar link to an audio file: #{I18n.t("search.audio")} link to a video file: #{I18n.t("search.video")}")
    end

    it "strips URLs correctly when blurb is longer than limit" do
      cooked = <<~RAW
        Here goes a test cooked with enough characters to hit the blurb limit.

        Something is very interesting about this audio file.

        http://localhost/uploads/default/original/1X/90adc0092b30c04b761541bc0322d0dce3d896e7.m4a
      RAW

      result = Search::GroupedSearchResults.blurb_for(cooked: cooked)
      expect(result).to eq("Here goes a test cooked with enough characters to hit the blurb limit. Something is very interesting about this audio file. #{I18n.t("search.audio")}")
    end

    it "does not fail on bad URLs" do
      cooked = <<~RAW
        invalid URL: http:error] should not trip up blurb generation.
      RAW
      result = Search::GroupedSearchResults.blurb_for(cooked: cooked)
      expect(result).to eq("invalid URL: http:error] should not trip up blurb generation.")
    end
  end

  context "#execute" do
    before do
      SiteSetting.tagging_enabled = true
    end

    context "staff tags" do
      fab!(:hidden_tag) { Fabricate(:tag) }
      let!(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }
      fab!(:topic) { Fabricate(:topic, tags: [hidden_tag]) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        SiteSetting.tagging_enabled = true

        SearchIndexer.enable
        SearchIndexer.index(hidden_tag, force: true)
        SearchIndexer.index(topic, force: true)
      end

      it "are visible to staff users" do
        result = Search.execute(hidden_tag.name, guardian: Guardian.new(Fabricate(:admin)))
        expect(result.tags).to contain_exactly(hidden_tag)
      end

      it "are hidden to regular users" do
        result = Search.execute(hidden_tag.name, guardian: Guardian.new(Fabricate(:user)))
        expect(result.tags).to contain_exactly()
      end
    end
  end

  context "custom_eager_load" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
    end

    it "includes custom tables" do
      begin
        SiteSetting.tagging_enabled = false
        expect(Search.execute("test").posts[0].topic.association(:category).loaded?).to be true
        expect(Search.execute("test").posts[0].topic.association(:tags).loaded?).to be false

        SiteSetting.tagging_enabled = true
        Search.custom_topic_eager_load([:topic_users])
        Search.custom_topic_eager_load() do
          [:bookmarks]
        end

        expect(Search.execute("test").posts[0].topic.association(:tags).loaded?).to be true
        expect(Search.execute("test").posts[0].topic.association(:topic_users).loaded?).to be true
        expect(Search.execute("test").posts[0].topic.association(:bookmarks).loaded?).to be true
      ensure
        SiteSetting.tagging_enabled = false
        Search.instance_variable_set(:@custom_topic_eager_loads, [])
      end
    end
  end

  context "users" do
    fab!(:user) { Fabricate(:user, username: "DonaldDuck") }
    fab!(:user2) { Fabricate(:user) }

    before do
      SearchIndexer.enable
      SearchIndexer.index(user, force: true)
    end

    it "finds users by their names or custom fields" do
      result = Search.execute("donaldduck", guardian: Guardian.new(user2))
      expect(result.users).to contain_exactly(user)

      user_field = Fabricate(:user_field, name: "custom field")
      UserCustomField.create!(user: user, value: "test", name: "user_field_#{user_field.id}")
      Jobs::ReindexSearch.new.execute({})
      result = Search.execute("test", guardian: Guardian.new(user2))
      expect(result.users).to be_empty

      user_field.update!(searchable: true)
      Jobs::ReindexSearch.new.execute({})
      result = Search.execute("test", guardian: Guardian.new(user2))
      expect(result.users).to contain_exactly(user)

      user_field2 = Fabricate(:user_field, name: "another custom field", searchable: true)
      UserCustomField.create!(user: user, value: "longer test", name: "user_field_#{user_field2.id}")
      UserCustomField.create!(user: user2, value: "second user test", name: "user_field_#{user_field2.id}")
      SearchIndexer.index(user, force: true)
      SearchIndexer.index(user2, force: true)
      result = Search.execute("test", guardian: Guardian.new(user2))

      expect(result.users.find { |u| u.id == user.id }.custom_data).to eq([
        { name: "custom field", value: "test" },
        { name: "another custom field", value: "longer test" }
      ])
      expect(result.users.find { |u| u.id == user2.id }.custom_data).to eq([
        { name: "another custom field", value: "second user test" }
      ])
    end
  end
end
