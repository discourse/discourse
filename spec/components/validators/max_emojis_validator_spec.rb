# encoding: UTF-8

require 'rails_helper'
require 'validators/max_emojis_validator'

describe MaxEmojisValidator do

  # simulate Rails behavior (singleton)
  def validate
    @validator ||= MaxEmojisValidator.new(attributes: :title)
    @validator.validate_each(record, :title, record.title)
  end

  shared_examples "validating any topic title" do
    it 'adds an error when emoji count is greater than SiteSetting.max_emojis_in_title' do
      SiteSetting.max_emojis_in_title = 3
      record.title = '🧐 Lots of emojis here 🎃 :joy: :sunglasses:'
      validate
      expect(record.errors[:title][0]).to eq(I18n.t("errors.messages.max_emojis", max_emojis_count: 3))
    end
  end

  describe 'topic' do
    let(:record) { Fabricate.build(:topic) }

    it 'does not add an error when emoji count is good' do
      SiteSetting.max_emojis_in_title = 2

      record.title = 'To Infinity and beyond! 🚀 :woman:t5:'
      validate
      expect(record.errors[:title]).to_not be_present
    end

    include_examples "validating any topic title"
  end

  describe 'private message' do
    let(:record) { Fabricate.build(:private_message_topic) }

    it 'does not add an error when emoji count is good' do
      SiteSetting.max_emojis_in_title = 1

      record.title = 'To Infinity and beyond! 🚀'
      validate
      expect(record.errors[:title]).to_not be_present
    end

    include_examples "validating any topic title"
  end
end
