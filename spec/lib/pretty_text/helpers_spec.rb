# frozen_string_literal: true

RSpec.describe PrettyText::Helpers do
  describe ".lookup_upload_urls" do
    let(:upload) { Fabricate(:upload) }

    it "should return cdn url if available" do
      short_url = upload.short_url
      result = PrettyText::Helpers.lookup_upload_urls([short_url])
      expect(result[short_url][:url]).to eq(upload.url)

      set_cdn_url "https://awesome.com"

      result = PrettyText::Helpers.lookup_upload_urls([short_url])
      expect(result[short_url][:url]).to eq("https://awesome.com#{upload.url}")
    end
  end

  describe ".category_tag_hashtag_lookup" do
    fab!(:tag) { Fabricate(:tag, name: "somecooltag") }
    fab!(:category) do
      Fabricate(:category, name: "Some Awesome Category", slug: "someawesomecategory")
    end

    it "handles tags based on slug with TAG_HASHTAG_POSTFIX" do
      expect(
        PrettyText::Helpers.category_tag_hashtag_lookup(
          +"somecooltag#{PrettyText::Helpers::TAG_HASHTAG_POSTFIX}",
        ),
      ).to eq([tag.url, "somecooltag"])
    end

    it "handles categories based on slug" do
      expect(PrettyText::Helpers.category_tag_hashtag_lookup("someawesomecategory")).to eq(
        [category.url, "someawesomecategory"],
      )
    end

    it "handles tags based on slug without TAG_HASHTAG_POSTFIX" do
      expect(PrettyText::Helpers.category_tag_hashtag_lookup(+"somecooltag")).to eq(
        [tag.url, "somecooltag"],
      )
    end

    it "returns nil when no tag or category that matches exists" do
      expect(PrettyText::Helpers.category_tag_hashtag_lookup("blah")).to eq(nil)
    end
  end
end
