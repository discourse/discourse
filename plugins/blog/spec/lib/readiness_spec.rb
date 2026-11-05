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

    it "reports a missing blog category" do
      SiteSetting.blog_category = ""

      expect(readiness.problems).to contain_exactly(
        have_attributes(key: :category, settings: %i[blog_category]),
      )
    end

    it "reports a read-restricted blog category" do
      category.update!(read_restricted: true)

      expect(readiness.problems).to contain_exactly(
        have_attributes(key: :category, settings: %i[blog_category]),
      )
    end

    it "reports a missing or public drafts category" do
      SiteSetting.blog_drafts_category = ""
      expect(readiness.problems.map(&:key)).to eq(%i[drafts_category])

      SiteSetting.blog_drafts_category = Fabricate(:category).id
      expect(described_class.new.problems).to contain_exactly(
        have_attributes(key: :drafts_category, settings: %i[blog_drafts_category]),
      )
    end

    it "reports a drafts category shared with groups outside the editorial roles" do
      drafts.set_permissions(:staff => :full, Fabricate(:group).name => :full)
      drafts.save!

      expect(readiness.problems.map(&:key)).to eq(%i[drafts_category])
    end

    it "accepts a drafts category shared with the editorial role groups" do
      writers = Fabricate(:group)
      SiteSetting.blog_contributor_groups = writers.id.to_s
      drafts.set_permissions(:staff => :full, writers.name => :full)
      drafts.save!

      expect(readiness.problems).to be_empty
    end

    it "reports a drafts category that is also the core shared drafts category" do
      SiteSetting.shared_drafts_category = drafts.id

      expect(readiness.problems.map(&:key)).to eq(%i[drafts_category])
    end

    it "lists every problem in the order they should be fixed" do
      SiteSetting.login_required = true
      SiteSetting.prevent_anons_from_downloading_files = true
      SiteSetting.blog_category = ""
      SiteSetting.blog_drafts_category = ""

      expect(readiness.problems.map(&:key)).to eq(
        %i[private_site anonymous_uploads category drafts_category],
      )
    end
  end

  describe "#ready?" do
    it "is true without problems and false with any" do
      expect(readiness.ready?).to eq(true)

      SiteSetting.blog_category = ""
      expect(described_class.new.ready?).to eq(false)
    end
  end

  describe "#error" do
    it "is nil when the blog is ready" do
      expect(readiness.error).to be_nil
    end

    it "is the message of the first problem" do
      SiteSetting.prevent_anons_from_downloading_files = true
      SiteSetting.blog_category = ""

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
