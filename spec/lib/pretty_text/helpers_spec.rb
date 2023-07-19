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

  describe ".hashtag_lookup" do
    fab!(:tag) { Fabricate(:tag, name: "somecooltag", description: "Coolest things ever") }
    fab!(:category) do
      Fabricate(
        :category,
        name: "Some Awesome Category",
        slug: "someawesomecategory",
        description: "Really great stuff here",
      )
    end
    fab!(:user) { Fabricate(:user) }

    it "handles tags and categories based on slug with type suffix" do
      expect(
        PrettyText::Helpers.hashtag_lookup("somecooltag::tag", user.id, %w[category tag]),
      ).to eq(
        {
          relative_url: tag.url,
          text: "somecooltag",
          description: "Coolest things ever",
          icon: "tag",
          id: tag.id,
          slug: "somecooltag",
          ref: "somecooltag::tag",
          type: "tag",
        },
      )
      expect(
        PrettyText::Helpers.hashtag_lookup(
          "someawesomecategory::category",
          user.id,
          %w[category tag],
        ),
      ).to eq(
        {
          relative_url: category.url,
          text: "Some Awesome Category",
          description: "Really great stuff here",
          icon: "folder",
          id: category.id,
          slug: "someawesomecategory",
          ref: "someawesomecategory::category",
          type: "category",
        },
      )
    end

    it "handles categories based on slug" do
      expect(
        PrettyText::Helpers.hashtag_lookup("someawesomecategory", user.id, %w[category tag]),
      ).to eq(
        {
          relative_url: category.url,
          text: "Some Awesome Category",
          description: "Really great stuff here",
          icon: "folder",
          id: category.id,
          slug: "someawesomecategory",
          ref: "someawesomecategory",
          type: "category",
        },
      )
    end

    it "handles tags and categories based on slug without type suffix" do
      expect(PrettyText::Helpers.hashtag_lookup("somecooltag", user.id, %w[category tag])).to eq(
        {
          relative_url: tag.url,
          text: "somecooltag",
          description: "Coolest things ever",
          icon: "tag",
          id: tag.id,
          slug: "somecooltag",
          ref: "somecooltag",
          type: "tag",
        },
      )
      expect(
        PrettyText::Helpers.hashtag_lookup("someawesomecategory", user.id, %w[category tag]),
      ).to eq(
        {
          relative_url: category.url,
          text: "Some Awesome Category",
          description: "Really great stuff here",
          icon: "folder",
          id: category.id,
          slug: "someawesomecategory",
          ref: "someawesomecategory",
          type: "category",
        },
      )
    end

    it "does not include categories the cooking user does not have access to" do
      group = Fabricate(:group)
      private_category =
        Fabricate(:private_category, slug: "secretcategory", name: "Manager Hideout", group: group)
      expect(PrettyText::Helpers.hashtag_lookup("secretcategory", user.id, %w[category tag])).to eq(
        nil,
      )

      GroupUser.create(group: group, user: user)
      expect(PrettyText::Helpers.hashtag_lookup("secretcategory", user.id, %w[category tag])).to eq(
        {
          relative_url: private_category.url,
          text: "Manager Hideout",
          description: nil,
          icon: "folder",
          id: private_category.id,
          slug: "secretcategory",
          ref: "secretcategory",
          type: "category",
        },
      )
    end

    it "does not return any results for disabled types" do
      SiteSetting.tagging_enabled = false
      expect(
        PrettyText::Helpers.hashtag_lookup("somecooltag::tag", user.id, %w[category tag]),
      ).to eq(nil)
    end

    it "returns nil when no tag or category that matches exists" do
      expect(PrettyText::Helpers.hashtag_lookup("blah", user.id, %w[category tag])).to eq(nil)
    end

    it "uses the system user if the cooking_user is nil" do
      guardian_system = Guardian.new(Discourse.system_user)
      Guardian.expects(:new).with(Discourse.system_user).returns(guardian_system)
      PrettyText::Helpers.hashtag_lookup("somecooltag", nil, %w[category tag])
    end
  end
end
