# frozen_string_literal: true

require "rails_helper"

describe Permalink do

  describe "normalization" do
    it "correctly normalizes" do
      normalizer = Permalink::Normalizer.new("/(\\/hello.*)\\?.*/\\1|/(\\/bye.*)\\?.*/\\1")

      expect(normalizer.normalize("/hello?a=1")).to eq("/hello")
      expect(normalizer.normalize("/bye?test=1")).to eq("/bye")
      expect(normalizer.normalize("/bla?a=1")).to eq("/bla?a=1")
    end
  end

  describe "new record" do
    it "strips blanks" do
      permalink = described_class.create(url: " my/old/url  ")
      expect(permalink.url).to eq("my/old/url")
    end

    it "removes leading slash" do
      permalink = described_class.create(url: "/my/old/url")
      expect(permalink.url).to eq("my/old/url")
    end
  end

  describe "target_url" do

    let(:permalink)       { Fabricate.build(:permalink) }
    let(:topic)           { Fabricate(:topic) }
    let(:post)            { Fabricate(:post, topic: topic) }
    let(:category)        { Fabricate(:category) }
    subject(:target_url)  { permalink.target_url }

    it "returns a topic url when topic_id is set" do
      permalink.topic_id = topic.id
      expect(target_url).to eq(topic.relative_url)
    end

    it "returns nil when topic_id is set but topic is not found" do
      permalink.topic_id = 99999
      expect(target_url).to eq(nil)
    end

    it "returns a post url when post_id is set" do
      permalink.post_id = post.id
      expect(target_url).to eq(post.url)
    end

    it "returns nil when post_id is set but post is not found" do
      permalink.post_id = 99999
      expect(target_url).to eq(nil)
    end

    it "returns a post url when post_id and topic_id are both set" do
      permalink.post_id = post.id
      permalink.topic_id = topic.id
      expect(target_url).to eq(post.url)
    end

    it "returns a category url when category_id is set" do
      permalink.category_id = category.id
      expect(target_url).to eq(category.url)
    end

    it "returns nil when category_id is set but category is not found" do
      permalink.category_id = 99999
      expect(target_url).to eq(nil)
    end

    it "returns a post url when topic_id, post_id, and category_id are all set for some reason" do
      permalink.post_id = post.id
      permalink.topic_id = topic.id
      permalink.category_id = category.id
      expect(target_url).to eq(post.url)
    end

    it "returns nil when nothing is set" do
      expect(target_url).to eq(nil)
    end
  end
end
