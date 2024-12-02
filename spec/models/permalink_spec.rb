# frozen_string_literal: true

RSpec.describe Permalink do
  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, topic: topic) }
  let(:category) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }
  let(:user) { Fabricate(:user) }

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
      permalink = described_class.create!(url: " my/old/url  ", topic_id: topic.id)
      expect(permalink.url).to eq("my/old/url")
    end

    it "removes leading slash" do
      permalink = described_class.create!(url: "/my/old/url", topic_id: topic.id)
      expect(permalink.url).to eq("my/old/url")
    end

    it "checks for unique URL" do
      permalink = described_class.create(url: "/my/old/url", topic_id: topic.id)
      expect(permalink.errors[:url]).to be_empty

      permalink = described_class.create(url: "/my/old/url", topic_id: topic.id)
      expect(permalink.errors[:url]).to be_present

      permalink = described_class.create(url: "my/old/url", topic_id: topic.id)
      expect(permalink.errors[:url]).to be_present
    end

    it "ensures that exactly one associated value is set" do
      permalink = described_class.create(url: "my/old/url")
      expect(permalink.errors[:base]).to be_present

      permalink = described_class.create(url: "my/old/url", topic_id: topic.id, post_id: post.id)
      expect(permalink.errors[:base]).to be_present

      permalink = described_class.create(url: "my/old/url", post_id: post.id)
      expect(permalink.errors[:base]).to be_empty
    end

    context "with special characters in URL" do
      it "percent encodes any special character" do
        permalink = described_class.create!(url: "/2022/10/03/привет-sam", topic_id: topic.id)
        expect(permalink.url).to eq("2022/10/03/%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82-sam")
      end

      it "checks for unique URL" do
        permalink = described_class.create(url: "/2022/10/03/привет-sam", topic_id: topic.id)
        expect(permalink.errors[:url]).to be_empty

        permalink = described_class.create(url: "/2022/10/03/привет-sam", topic_id: topic.id)
        expect(permalink.errors[:url]).to be_present
      end
    end
  end

  describe "target_url" do
    subject(:target_url) { permalink.target_url }

    let(:permalink) { Fabricate.build(:permalink) }

    it "returns nil when nothing is set" do
      expect(target_url).to eq(nil)
    end

    context "when `topic_id` is set" do
      it "returns an absolute path" do
        permalink.topic_id = topic.id
        expect(target_url).to eq(topic.relative_url)
        expect(target_url).not_to start_with("http")
      end

      it "returns nil when topic is not found" do
        permalink.topic_id = 99_999
        expect(target_url).to eq(nil)
      end
    end

    context "when `post_id` is set" do
      it "returns an absolute path" do
        permalink.post_id = post.id
        expect(target_url).to eq(post.relative_url)
        expect(target_url).not_to start_with("http")
      end

      it "returns nil when post is not found" do
        permalink.post_id = 99_999
        expect(target_url).to eq(nil)
      end
    end

    context "when `category_id` is set" do
      it "returns an absolute path" do
        permalink.category_id = category.id
        expect(target_url).to eq(category.url)
        expect(target_url).not_to start_with("http")
      end

      it "returns nil when category is not found" do
        permalink.category_id = 99_999
        expect(target_url).to eq(nil)
      end
    end

    context "when `tag_id` is set" do
      it "returns an absolute path" do
        permalink.tag_id = tag.id
        expect(target_url).to eq(tag.relative_url)
        expect(target_url).not_to start_with("http")
      end

      it "returns nil when tag is not found" do
        permalink.tag_id = 99_999
        expect(target_url).to eq(nil)
      end
    end

    context "when `user_id` is set" do
      it "returns an absolute path" do
        permalink.user_id = user.id
        expect(target_url).to eq(user.relative_url)
        expect(target_url).not_to start_with("http")
      end

      it "returns nil when user is not found" do
        permalink.user_id = 99_999
        expect(target_url).to eq(nil)
      end
    end

    context "when `external_url` is set" do
      it "returns a URL when an absolute URL is set" do
        permalink.external_url = "https://example.com"
        expect(target_url).to eq("https://example.com")
      end

      it "returns a protocol-relative URL when a PRURL is set" do
        permalink.external_url = "//example.com"
        expect(target_url).to eq("//example.com")
      end

      it "returns an absolute path when an absolute path is set" do
        permalink.external_url = "/my/preferences"
        expect(target_url).to eq("/my/preferences")
      end

      it "returns a relative path when a relative path is set" do
        permalink.external_url = "foo/bar"
        expect(target_url).to eq("foo/bar")
      end
    end

    context "with subfolder" do
      before { set_subfolder "/community" }

      context "when `topic_id` is set" do
        it "returns an absolute path" do
          permalink.topic_id = topic.id
          expect(target_url).to eq(topic.relative_url)
          expect(target_url).to start_with("/community/")
        end
      end

      context "when `post_id` is set" do
        it "returns an absolute path" do
          permalink.post_id = post.id
          expect(target_url).to eq(post.relative_url)
          expect(target_url).to start_with("/community/")
        end
      end

      context "when `category_id` is set" do
        it "returns an absolute path" do
          permalink.category_id = category.id
          expect(target_url).to eq(category.url)
          expect(target_url).to start_with("/community/")
        end
      end

      context "when `tag_id` is set" do
        it "returns an absolute path" do
          permalink.tag_id = tag.id
          expect(target_url).to eq(tag.relative_url)
          expect(target_url).to start_with("/community/")
        end
      end

      context "when `user_id` is set" do
        it "returns an absolute path" do
          permalink.user_id = user.id
          expect(target_url).to eq(user.relative_url)
          expect(target_url).to start_with("/community/")
        end
      end

      context "when `external_url` is set" do
        it "returns a URL when an absolute URL is set" do
          permalink.external_url = "https://example.com"
          expect(target_url).to eq("https://example.com")
        end

        it "returns a protocol-relative URL when a PRURL is set" do
          permalink.external_url = "//example.com"
          expect(target_url).to eq("//example.com")
        end

        it "returns an absolute path when an absolute path is set" do
          permalink.external_url = "/my/preferences"
          expect(target_url).to eq("/community/my/preferences")
        end

        it "returns a relative path when a relative path is set" do
          permalink.external_url = "foo/bar"
          expect(target_url).to eq("foo/bar")
        end
      end
    end

    it "returns the highest priority url when multiple attributes are set" do
      permalink.external_url = "/my/preferences"
      permalink.post = post
      permalink.topic = topic
      permalink.category = category
      permalink.tag = tag
      permalink.user = user

      expect(permalink.target_url).to eq("/my/preferences")

      permalink.external_url = nil
      expect(permalink.target_url).to eq(post.relative_url)

      permalink.post = nil
      expect(permalink.target_url).to eq(topic.relative_url)

      permalink.topic = nil
      expect(permalink.target_url).to eq(category.relative_url)

      permalink.category = nil
      expect(permalink.target_url).to eq(tag.relative_url)

      permalink.tag = nil
      expect(permalink.target_url).to eq(user.relative_url)

      permalink.user = nil
      expect(permalink.target_url).to be_nil
    end
  end
end
