# frozen_string_literal: true

describe LocalizationGuardian do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)
  fab!(:post) { Fabricate(:post, user: user) }
  fab!(:other_user_post, :post)

  before { SiteSetting.content_localization_enabled = true }

  describe "#can_localize_content?" do
    it "returns false when content localization is disabled" do
      SiteSetting.content_localization_enabled = false
      expect(Guardian.new(admin).can_localize_content?).to eq(false)
    end

    it "returns true for users in allowed groups" do
      SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}"
      expect(Guardian.new(admin).can_localize_content?).to eq(true)
    end

    it "returns false for users not in allowed groups" do
      SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}"
      expect(Guardian.new(user).can_localize_content?).to eq(false)
    end
  end

  describe "#can_localize_post?" do
    it "returns false when content localization is disabled" do
      SiteSetting.content_localization_enabled = false
      expect(Guardian.new(user).can_localize_post?(post)).to eq(false)
    end

    context "when user is in allowed groups" do
      before { SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}" }

      it "returns true for any post" do
        expect(Guardian.new(admin).can_localize_post?(post)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(post.id)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(other_user_post)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(other_user_post.id)).to eq(true)
      end
    end

    context "when author localization is enabled" do
      before do
        SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}"
        SiteSetting.content_localization_allow_author_localization = true
      end

      it "returns true when user is the post author" do
        expect(Guardian.new(user).can_localize_post?(post)).to eq(true)
        expect(Guardian.new(user).can_localize_post?(post.id)).to eq(true)
      end

      it "returns false when user is not the post author" do
        expect(Guardian.new(user).can_localize_post?(other_user_post)).to eq(false)
        expect(Guardian.new(user).can_localize_post?(other_user_post.id)).to eq(false)
      end

      it "returns true for users in allowed groups regardless of authorship" do
        expect(Guardian.new(admin).can_localize_post?(post)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(post.id)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(other_user_post)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(other_user_post.id)).to eq(true)
      end
    end

    context "when author localization is disabled" do
      before do
        SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}"
        SiteSetting.content_localization_allow_author_localization = false
      end

      it "returns false for post authors not in allowed groups" do
        expect(Guardian.new(user).can_localize_post?(post)).to eq(false)
        expect(Guardian.new(user).can_localize_post?(post.id)).to eq(false)
      end

      it "returns true for users in allowed groups" do
        expect(Guardian.new(admin).can_localize_post?(post)).to eq(true)
        expect(Guardian.new(admin).can_localize_post?(post.id)).to eq(true)
      end
    end
  end
end
