# frozen_string_literal: true

describe LocalizationAttributesReplacer do
  describe ".replace_category_attributes" do
    fab!(:category) { Fabricate(:category, locale: "en") }
    fab!(:subcategory) { Fabricate(:category, parent_category: category, locale: "en") }
    fab!(:ja_subcategory) do
      Fabricate(:category_localization, category: subcategory, locale: "ja", name: "猫犬")
    end
    fab!(:ja_category) { Fabricate(:category_localization, category:, locale: "ja", name: "猫犬") }

    it "replaces category and subcategory attributes with localized value" do
      LocalizationAttributesReplacer.replace_category_attributes(subcategory, "ja")

      expect(subcategory.name).to eq(ja_subcategory.name)
      expect(subcategory.description).to eq(ja_subcategory.description)
      expect(subcategory.parent_category.name).to eq(ja_category.name)
      expect(subcategory.parent_category.description).to eq(ja_category.description)
    end

    it "does not change the name if the locale is the same" do
      LocalizationAttributesReplacer.replace_category_attributes(category, "en")

      expect(category.name).to eq(category.name)
    end

    it "does not change attributes if no localization exists for the given locale" do
      LocalizationAttributesReplacer.replace_category_attributes(category, "fr")

      expect(category.name).to eq(category.name)
    end
  end

  describe ".replace_topic_attributes" do
    fab!(:topic) { Fabricate(:topic, locale: "en") }
    fab!(:ja_localization) do
      Fabricate(:topic_localization, topic:, locale: "ja", title: "猫犬", excerpt: "柴犬は猫のような犬です。")
    end

    it "replaces the title and excerpt with localized values" do
      LocalizationAttributesReplacer.replace_topic_attributes(topic, "ja")

      expect(topic.title).to eq(ja_localization.title)
      expect(topic.excerpt).to eq(ja_localization.excerpt)
    end

    it "does not change the title or excerpt if the locale is the same" do
      LocalizationAttributesReplacer.replace_topic_attributes(topic, "en")

      expect(topic.title).to eq(topic.title)
      expect(topic.excerpt).to eq(topic.excerpt)
    end

    it "does not change attributes if no localization exists for the given locale" do
      LocalizationAttributesReplacer.replace_topic_attributes(topic, "fr")

      expect(topic.title).to eq(topic.title)
      expect(topic.excerpt).to eq(topic.excerpt)
    end

    it "does not error out if topic does not exist" do
      expect {
        LocalizationAttributesReplacer.replace_topic_attributes(nil, "ja")
      }.not_to raise_error
    end
  end

  describe ".replace_post_attributes" do
    fab!(:post) { Fabricate(:post, locale: "en") }
    fab!(:ja_localization) do
      Fabricate(:post_localization, post:, locale: "ja", cooked: "猫犬は柴犬のような猫です。")
    end

    it "replaces the cooked content with localized values" do
      LocalizationAttributesReplacer.replace_post_attributes(post, "ja")

      expect(post.cooked).to eq(ja_localization.cooked)
    end

    it "does not change the cooked content if the locale is the same" do
      LocalizationAttributesReplacer.replace_post_attributes(post, "en")

      expect(post.cooked).to eq(post.cooked)
    end

    it "does not change attributes if no localization exists for the given locale" do
      LocalizationAttributesReplacer.replace_post_attributes(post, "fr")

      expect(post.cooked).to eq(post.cooked)
    end
  end
end
