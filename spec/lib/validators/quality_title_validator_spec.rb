# encoding: UTF-8
# frozen_string_literal: true

require 'ostruct'

module QualityTitleValidatorSpec
  class Validatable < OpenStruct
    include ActiveModel::Validations
    validates :title, quality_title: { unless: :private_message? }
  end
end

describe "A record validated with QualityTitleValidator" do
  let(:valid_title) { "hello this is my cool topic! welcome: all;" }
  let(:short_title) { valid_title.slice(0, SiteSetting.min_topic_title_length - 1) }
  let(:long_title) { valid_title.center(SiteSetting.max_topic_title_length + 1, 'x') }
  let(:xxxxx_title) { valid_title.gsub(/./, 'x') }

  let(:meaningless_title) { "asdf asdf asdf" }
  let(:loud_title) { "ALL CAPS INVALID TITLE" }
  let(:pretentious_title) { "superverylongwordintitlefornoparticularreason" }

  subject(:topic) { QualityTitleValidatorSpec::Validatable.new }

  before(:each) do
    topic.stubs(private_message?: false)
  end

  it "allows a regular title with a few ascii characters" do
    topic.title = valid_title
    expect(topic).to be_valid
  end

  it "allows non ascii" do
    topic.title = "Iñtërnâtiônàlizætiøn"
    expect(topic).to be_valid
  end

  it 'allows Chinese characters' do
    topic.title = '现在发现使用中文标题没法发帖子了'
    expect(topic).to be_valid
  end

  it "allows anything in a private message" do
    topic.stubs(private_message?: true)
    [short_title, long_title, xxxxx_title].each do |bad_title|
      topic.title = bad_title
      expect(topic).to be_valid
    end
  end

  it "strips a title when identifying length" do
    topic.title = short_title.center(SiteSetting.min_topic_title_length + 1, ' ')
    expect(topic).not_to be_valid
  end

  it "doesn't allow a long title" do
    topic.title = long_title
    expect(topic).not_to be_valid
  end

  it "doesn't allow a short title" do
    topic.title = short_title
    expect(topic).not_to be_valid
  end

  it "doesn't allow a title of one repeated character" do
    topic.title = xxxxx_title
    expect(topic).not_to be_valid
  end

  it "doesn't allow a meaningless title" do
    topic.title = meaningless_title
    expect(topic).not_to be_valid
    expect(topic.errors.full_messages.first).to include(I18n.t("errors.messages.is_invalid_meaningful"))
  end

  it "doesn't allow a pretentious title" do
    topic.title = pretentious_title
    expect(topic).not_to be_valid
    expect(topic.errors.full_messages.first).to include(I18n.t("errors.messages.is_invalid_unpretentious"))
  end

  it "doesn't allow a loud title" do
    topic.title = loud_title
    expect(topic).not_to be_valid
    expect(topic.errors.full_messages.first).to include(I18n.t("errors.messages.is_invalid_quiet"))
  end
end
