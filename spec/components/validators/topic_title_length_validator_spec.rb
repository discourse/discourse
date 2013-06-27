# encoding: UTF-8

require 'spec_helper'
require 'validators/topic_title_length_validator'

describe TopicTitleLengthValidator do

  let(:validator) { TopicTitleLengthValidator.new({attributes: :title}) }
  subject(:validate) { validator.validate_each(record,:title,record.title) }

  shared_examples "validating any topic title" do
    it 'adds an error when topic title is greater than SiteSetting.max_topic_title_length' do
      record.title = 'a' * (SiteSetting.max_topic_title_length + 1)
      validate
      expect(record.errors[:title]).to be_present
    end
  end

  describe 'topic' do
    let(:record) { Fabricate.build(:topic) }

    it 'adds an error when topic title is shorter than SiteSetting.min_topic_title_length' do
      record.title = 'a' * (SiteSetting.min_topic_title_length - 1)
      validate
      expect(record.errors[:title]).to be_present
    end

    it 'does not add an error when length is good' do
      record.title = 'a' * (SiteSetting.min_topic_title_length)
      validate
      expect(record.errors[:title]).to_not be_present
    end

    include_examples "validating any topic title"
  end

  describe 'private message' do
    before do
      SiteSetting.stubs(:min_private_message_title_length).returns(3)
    end

    let(:record) { Fabricate.build(:private_message_topic) }

    it 'adds an error when topic title is shorter than SiteSetting.min_private_message_title_length' do
      record.title = 'a' * (SiteSetting.min_private_message_title_length - 1)
      validate
      expect(record.errors[:title]).to be_present
    end

    it 'does not add an error when topic title is shorter than SiteSetting.min_topic_title_length' do
      SiteSetting.stubs(:min_topic_title_length).returns(15)
      record.title = 'a' * (SiteSetting.min_private_message_title_length)
      validate
      expect(record.errors[:title]).to_not be_present
    end

    include_examples "validating any topic title"
  end

end
