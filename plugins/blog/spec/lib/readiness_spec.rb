# frozen_string_literal: true

RSpec.describe Blog::Readiness do
  subject(:readiness) { described_class.new }

  fab!(:category)
  fab!(:drafts) { Fabricate(:private_category, group: Group[:staff]) }

  before { enable_blog!(category:, drafts:) }

  describe "#problems" do
    it "is empty for a public blog category and a private drafts category" do
      expect(readiness.problems).to be_empty
    end

    it "reports a login-required site" do
      SiteSetting.login_required = true

      expect(readiness.problems).to contain_exactly(
        have_attributes(key: :private_site, settings: %i[login_required]),
      )
    end

    it "reports secure uploads as a private site" do
      enable_secure_uploads

      expect(readiness.problems).to contain_exactly(
        have_attributes(key: :private_site, settings: %i[secure_uploads]),
      )
    end

    it "reports anonymous upload restrictions" do
      SiteSetting.prevent_anons_from_downloading_files = true

      expect(readiness.problems).to contain_exactly(
        have_attributes(
          key: :anonymous_uploads,
          settings: %i[prevent_anons_from_downloading_files],
        ),
      )
    end

    it "accepts missing categories, which the blog creates when it needs them" do
      SiteSetting.blog_category = ""
      SiteSetting.blog_drafts_category = ""

      expect(readiness.problems).to be_empty
    end

    it "reports a read-restricted blog category" do
      category.update!(read_restricted: true)

      expect(readiness.problems).to contain_exactly(
        have_attributes(key: :category, settings: %i[blog_category]),
      )
    end

    it "reports a missing blog category when its default name is already taken" do
      SiteSetting.blog_category = ""
      Fabricate(:category, name: I18n.t("blog.categories.public"))

      expect(readiness.problems).to contain_exactly(
        have_attributes(key: :category_name_taken, settings: %i[blog_category]),
      )
      expect(readiness.error).to eq(
        I18n.t("blog.errors.category_name_taken", name: I18n.t("blog.categories.public")),
      )
    end

    it "lists every problem in the order they should be fixed" do
      SiteSetting.login_required = true
      SiteSetting.prevent_anons_from_downloading_files = true
      category.update!(read_restricted: true)

      expect(readiness.problems.map(&:key)).to eq(%i[private_site anonymous_uploads category])
    end
  end

  describe ".valid_drafts_category?" do
    it "accepts a private category shared with staff and the editorial role groups" do
      writers = Fabricate(:group)
      SiteSetting.blog_contributor_groups = writers.id.to_s
      drafts.set_permissions(:staff => :full, writers.name => :full)
      drafts.save!

      expect(described_class.valid_drafts_category?(drafts)).to eq(true)
    end

    it "rejects a missing or public category" do
      expect(described_class.valid_drafts_category?(nil)).to eq(false)
      expect(described_class.valid_drafts_category?(category)).to eq(false)
    end

    it "rejects a category shared with groups outside the editorial roles" do
      drafts.set_permissions(:staff => :full, Fabricate(:group).name => :full)
      drafts.save!

      expect(described_class.valid_drafts_category?(drafts)).to eq(false)
    end

    it "rejects the core shared drafts category" do
      SiteSetting.shared_drafts_category = drafts.id

      expect(described_class.valid_drafts_category?(drafts)).to eq(false)
    end
  end

  describe "#ready?" do
    it "is true without problems and false with any" do
      expect(readiness.ready?).to eq(true)

      category.update!(read_restricted: true)
      expect(described_class.new.ready?).to eq(false)
    end
  end

  describe "#error" do
    it "is nil when the blog is ready" do
      expect(readiness.error).to be_nil
    end

    it "is the message of the first problem" do
      SiteSetting.prevent_anons_from_downloading_files = true
      category.update!(read_restricted: true)

      expect(readiness.error).to eq(I18n.t("blog.errors.anonymous_uploads"))
    end
  end

  describe "#ensure!" do
    it "does nothing when the blog is ready" do
      expect { readiness.ensure! }.not_to raise_error
    end

    it "raises the first problem's message as invalid parameters" do
      SiteSetting.login_required = true

      expect { readiness.ensure! }.to raise_error(
        Discourse::InvalidParameters,
        I18n.t("blog.errors.private_site"),
      )
    end
  end
end
