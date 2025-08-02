# encoding: UTF-8
# frozen_string_literal: true

RSpec.describe MaxEmojisValidator do
  # simulate Rails behavior (singleton)
  def validate
    @validator ||= MaxEmojisValidator.new(attributes: :title)
    @validator.validate_each(record, :title, record.title)
  end

  shared_examples "validating any topic title" do
    before do
      SiteSetting.max_emojis_in_title = 3
      CustomEmoji.create!(name: "trout", upload: Fabricate(:upload))
      Emoji.clear_cache
    end

    it "adds an error when emoji count is greater than SiteSetting.max_emojis_in_title" do
      record.title = "🧐 Lots of emojis here 🎃 :trout: :)"
      validate
      expect(record.errors[:title][0]).to eq(
        I18n.t("errors.messages.max_emojis", max_emojis_count: 3),
      )
    end

    it "does not add an error when emoji count is exactly SiteSetting.max_emojis_in_title" do
      record.title = ":joy: :blush: :smile: is not only about emojis: Happiness::start()"
      validate
      expect(record.valid?).to be true
    end

    it "counts emojis with variation selectors" do
      record.title = "Title with emojis ☠️☠️☠️☠️"
      validate
      expect(record.errors[:title][0]).to eq(
        I18n.t("errors.messages.max_emojis", max_emojis_count: 3),
      )
    end
  end

  describe "topic" do
    let(:record) { Fabricate.build(:topic) }

    it "does not add an error when emoji count is good" do
      SiteSetting.max_emojis_in_title = 2

      record.title = "To Infinity and beyond! 🚀 :woman:t5:"
      validate
      expect(record.errors[:title]).to_not be_present
    end

    include_examples "validating any topic title"
  end

  describe "private message" do
    let(:record) { Fabricate.build(:private_message_topic) }

    it "does not add an error when emoji count is good" do
      SiteSetting.max_emojis_in_title = 1

      record.title = "To Infinity and beyond! 🚀"
      validate
      expect(record.errors[:title]).to_not be_present
    end

    include_examples "validating any topic title"
  end
end
