# frozen_string_literal: true

RSpec.describe PublishedPage, type: :model do
  fab!(:topic) { Fabricate(:topic) }

  it "has path and url helpers" do
    pp = PublishedPage.create!(topic: topic, slug: "hello-world")
    expect(pp.path).to eq("/pub/hello-world")
    expect(pp.url).to eq(Discourse.base_url + "/pub/hello-world")
  end

  it "validates the slug" do
    expect(PublishedPage.new(topic: topic, slug: "this-is-valid")).to be_valid
    expect(PublishedPage.new(topic: topic, slug: "10_things_i_hate_about_slugs")).to be_valid
    expect(PublishedPage.new(topic: topic, slug: "YELLING")).to be_valid

    expect(PublishedPage.new(topic: topic, slug: "how about some space")).not_to be_valid
    expect(PublishedPage.new(topic: topic, slug: "slugs are %%%%")).not_to be_valid

    expect(PublishedPage.new(topic: topic, slug: "check-slug")).not_to be_valid
    expect(PublishedPage.new(topic: topic, slug: "by-topic")).not_to be_valid
  end
end
