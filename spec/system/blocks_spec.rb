# frozen_string_literal: true

describe "Block conditions", type: :system do
  fab!(:theme) do
    theme_dir = "#{Rails.root}/spec/fixtures/themes/dev-tools-test-theme"
    theme = RemoteTheme.import_theme_from_directory(theme_dir)
    Theme.find(SiteSetting.default_theme_id).child_themes << theme
    theme
  end

  fab!(:admin)
  fab!(:moderator)
  fab!(:trust_level_2_user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:trust_level_1_user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:trust_level_0_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:category)
  fab!(:post)
  fab!(:topic) { post.topic }

  let(:blocks) { PageObjects::Components::Blocks.new }

  describe "user conditions" do
    context "when anonymous" do
      it "hides logged-in-only blocks" do
        visit("/latest")

        expect(blocks).to have_no_block("user-logged-in")
        expect(blocks).to have_no_block("user-admin")
        expect(blocks).to have_no_block("user-moderator")
        expect(blocks).to have_no_block("user-trust-level-2")
      end
    end

    context "when logged in as regular user (TL0)" do
      before { sign_in(trust_level_0_user) }

      it "shows logged-in blocks but not role-specific blocks" do
        visit("/latest")

        expect(blocks).to have_block("user-logged-in")
        expect(blocks).to have_no_block("user-admin")
        expect(blocks).to have_no_block("user-moderator")
        expect(blocks).to have_no_block("user-trust-level-2")
      end
    end

    context "when logged in as TL2 user" do
      before { sign_in(trust_level_2_user) }

      it "shows trust level blocks" do
        visit("/latest")

        expect(blocks).to have_block("user-logged-in")
        expect(blocks).to have_block("user-trust-level-2")
        expect(blocks).to have_no_block("user-admin")
      end
    end

    context "when logged in as moderator" do
      before { sign_in(moderator) }

      it "shows moderator blocks" do
        visit("/latest")

        expect(blocks).to have_block("user-logged-in")
        expect(blocks).to have_block("user-moderator")
        expect(blocks).to have_no_block("user-admin")
      end
    end

    context "when logged in as admin" do
      before { sign_in(admin) }

      it "shows admin blocks" do
        visit("/latest")

        expect(blocks).to have_block("user-logged-in")
        expect(blocks).to have_block("user-admin")
        # Admins are also moderators
        expect(blocks).to have_block("user-moderator")
      end
    end
  end

  describe "route conditions" do
    before { sign_in(trust_level_2_user) }

    it "shows discovery blocks on discovery pages" do
      visit("/latest")

      expect(blocks).to have_block("route-discovery")
      expect(blocks).to have_no_block("route-category")
      expect(blocks).to have_no_block("route-topic")
    end

    it "shows category blocks on category pages" do
      visit("/c/#{category.slug}/#{category.id}")

      expect(blocks).to have_block("route-discovery")
      expect(blocks).to have_block("route-category")
      expect(blocks).to have_no_block("route-topic")
    end

    it "shows topic blocks on topic pages" do
      visit("/t/#{topic.slug}/#{topic.id}")

      expect(blocks).to have_block("route-topic")
      expect(blocks).to have_no_block("route-discovery")
      expect(blocks).to have_no_block("route-category")
    end
  end

  describe "route navigation (SPA)" do
    before { sign_in(trust_level_2_user) }

    it "re-evaluates blocks when navigating from discovery to topic via click" do
      visit("/latest")

      expect(blocks).to have_block("route-discovery")
      expect(blocks).to have_no_block("route-topic")

      find(".topic-list-item .raw-topic-link[data-topic-id='#{topic.id}']").click

      expect(blocks).to have_block("route-topic")
      expect(blocks).to have_no_block("route-discovery")
    end

    it "re-evaluates blocks when navigating from topic back to discovery" do
      visit("/t/#{topic.slug}/#{topic.id}")

      expect(blocks).to have_block("route-topic")
      expect(blocks).to have_no_block("route-discovery")

      find("#site-logo").click

      expect(blocks).to have_block("route-discovery")
      expect(blocks).to have_no_block("route-topic")
    end

    it "re-evaluates combined conditions when navigating to category page" do
      sign_in(admin)
      visit("/latest")

      expect(blocks).to have_no_block("combined-admin-category")

      find(".sidebar-section-link", text: category.name).click

      expect(blocks).to have_block("combined-admin-category")
    end
  end

  describe "setting conditions" do
    before { sign_in(trust_level_2_user) }

    context "when enable_badges is true" do
      before { SiteSetting.enable_badges = true }

      it "shows setting-dependent block" do
        visit("/latest")

        expect(blocks).to have_block("setting-badges-enabled")
      end
    end

    context "when enable_badges is false" do
      before { SiteSetting.enable_badges = false }

      it "hides setting-dependent block" do
        visit("/latest")

        expect(blocks).to have_no_block("setting-badges-enabled")
      end
    end
  end

  describe "combined conditions (AND logic)" do
    context "with logged-in + TL1 requirement" do
      it "hides block when not logged in" do
        visit("/latest")

        expect(blocks).to have_no_block("combined-logged-in-tl1")
      end

      it "hides block when logged in but below TL1" do
        sign_in(trust_level_0_user)
        visit("/latest")

        expect(blocks).to have_no_block("combined-logged-in-tl1")
      end

      it "shows block when logged in and at TL1+" do
        sign_in(trust_level_1_user)
        visit("/latest")

        expect(blocks).to have_block("combined-logged-in-tl1")
      end
    end

    context "with admin + category route requirement" do
      it "hides block when admin but not on category page" do
        sign_in(admin)
        visit("/latest")

        expect(blocks).to have_no_block("combined-admin-category")
      end

      it "hides block when on category page but not admin" do
        sign_in(trust_level_2_user)
        visit("/c/#{category.slug}/#{category.id}")

        expect(blocks).to have_no_block("combined-admin-category")
      end

      it "shows block when admin AND on category page" do
        sign_in(admin)
        visit("/c/#{category.slug}/#{category.id}")

        expect(blocks).to have_block("combined-admin-category")
      end
    end
  end

  describe "OR conditions (any combinator)" do
    it "hides block when neither admin nor moderator" do
      sign_in(trust_level_2_user)
      visit("/latest")

      expect(blocks).to have_no_block("or-admin-or-moderator")
    end

    it "shows block when moderator (not admin)" do
      sign_in(moderator)
      visit("/latest")

      expect(blocks).to have_block("or-admin-or-moderator")
    end

    it "shows block when admin (not just moderator)" do
      sign_in(admin)
      visit("/latest")

      expect(blocks).to have_block("or-admin-or-moderator")
    end
  end

  describe "block ordering" do
    before { sign_in(trust_level_2_user) }

    it "renders blocks in the order they were configured" do
      visit("/latest")

      expect(blocks).to have_block("order-first")
      expect(blocks).to have_block("order-second")
      expect(blocks).to have_block("order-third")
      expect(blocks).to have_block("order-fourth")
      expect(blocks).to have_block("order-fifth")

      expect(blocks.has_blocks_in_order?([1, 2, 3, 4, 5])).to be true
    end
  end

  describe "viewport conditions" do
    before { sign_in(trust_level_2_user) }

    context "when on desktop viewport (default)" do
      it "shows desktop-only blocks and hides mobile-only blocks" do
        visit("/latest")

        expect(blocks).to have_block("viewport-desktop")
        expect(blocks).to have_no_block("viewport-mobile")
      end
    end

    context "when on mobile viewport", mobile: true do
      it "shows mobile-only blocks and hides desktop-only blocks" do
        visit("/latest")

        expect(blocks).to have_block("viewport-mobile")
        expect(blocks).to have_no_block("viewport-desktop")
      end
    end
  end
end
