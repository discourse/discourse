# frozen_string_literal: true

RSpec.describe TagSerializer do
  fab!(:user)
  fab!(:admin)
  fab!(:tag)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:topic_in_public_category) { Fabricate(:topic, tags: [tag]) }
  fab!(:topic_in_private_category) { Fabricate(:topic, category: private_category, tags: [tag]) }

  describe "#slug" do
    it "includes the slug attribute" do
      serialized = described_class.new(tag, scope: Guardian.new(user), root: false).as_json
      expect(serialized[:slug]).to eq(tag.slug)
    end
  end

  describe "#topic_count" do
    it "should return the value of `Tag#public_topic_count` for a non-staff user" do
      serialized = described_class.new(tag, scope: Guardian.new(user), root: false).as_json

      expect(serialized[:topic_count]).to eq(1)
    end

    it "should return the value of `Tag#topic_count` for a staff user" do
      serialized = described_class.new(tag, scope: Guardian.new(admin), root: false).as_json

      expect(serialized[:topic_count]).to eq(2)
    end
  end

  describe "localization" do
    fab!(:localized_tag, :tag) { Fabricate(:tag, name: "cats", locale: "en") }
    fab!(:localization) do
      Fabricate(
        :tag_localization,
        tag: localized_tag,
        locale: "ja",
        name: "猫",
        description: "猫についてのタグです",
      )
    end

    def serialize(tag)
      described_class.new(tag, scope: Guardian.new(user), root: false).as_json
    end

    describe "#name" do
      it "returns localized name when conditions met" do
        SiteSetting.content_localization_enabled = true
        localized_tag.update!(locale: "en")
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:name]).to eq("猫")
      end

      it "returns original name when localization disabled" do
        SiteSetting.content_localization_enabled = false
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:name]).to eq("cats")
      end

      it "returns original name when tag has no locale" do
        SiteSetting.content_localization_enabled = true
        localized_tag.update!(locale: nil)
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:name]).to eq("cats")
      end

      it "returns original name when tag is in user locale" do
        SiteSetting.content_localization_enabled = true
        localized_tag.update!(locale: "ja")
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:name]).to eq("cats")
      end
    end

    describe "#description" do
      it "returns localized description when conditions met" do
        SiteSetting.content_localization_enabled = true
        localized_tag.update!(locale: "en", description: "A tag about cats")
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:description]).to eq("猫についてのタグです")
      end

      it "returns original description when localization disabled" do
        SiteSetting.content_localization_enabled = false
        localized_tag.update!(description: "A tag about cats")
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:description]).to eq("A tag about cats")
      end

      it "returns original description when tag has no locale" do
        SiteSetting.content_localization_enabled = true
        localized_tag.update!(locale: nil, description: "A tag about cats")
        I18n.locale = "ja"

        expect(serialize(localized_tag)[:description]).to eq("A tag about cats")
      end
    end
  end
end
