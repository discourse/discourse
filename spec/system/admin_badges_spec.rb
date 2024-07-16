# frozen_string_literal: true

describe "Admin Badges Page", type: :system do
  before { SiteSetting.enable_badges = true }

  fab!(:current_user) { Fabricate(:admin) }

  let(:badges_page) { PageObjects::Pages::AdminBadges.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }

  before { sign_in(current_user) }

  context "with system badge" do
    it "displays badge" do
      badges_page.visit_page(Badge::Autobiographer)

      badge = Badge.find(Badge::Autobiographer)

      expect(form).to have_an_alert(I18n.t("admin_js.admin.badges.disable_system"))
      expect(form.field("badge_type_id")).to be_disabled
      expect(form.field("badge_type_id")).to have_value(BadgeType::Bronze.to_s)
      expect(form.field("badge_grouping_id")).to be_disabled
      expect(form.field("badge_grouping_id")).to have_value(BadgeGrouping::GettingStarted.to_s)
      expect(form.field("allow_title")).to be_enabled
      expect(form.field("allow_title")).to be_unchecked
      expect(form.field("multiple_grant")).to be_disabled
      expect(form.field("multiple_grant")).to be_unchecked
      expect(form.field("listable")).to be_disabled
      expect(form.field("listable")).to be_checked
      expect(form.field("show_posts")).to be_disabled
      expect(form.field("show_posts")).to be_unchecked
      expect(form.field("icon")).to be_enabled
      expect(form.field("icon")).to have_value("user-edit")
      expect(find(".form-kit__container[data-name='name']")).to have_content(badge.name.strip)
      expect(find(".form-kit__container[data-name='description']")).to have_content(
        badge.description.strip,
      )
      expect(find(".form-kit__container[data-name='long_description']")).to have_content(
        badge.long_description.strip,
      )
    end
  end

  context "when creating a badge" do
    it "creates a badge" do
      badges_page.new_page

      form.field("enabled").accept
      form.field("name").fill_in("a name")
      form.field("badge_type_id").select(BadgeType::Bronze)
      form.field("icon").select("ambulance")
      form.field("description").fill_in("a description")
      form.field("long_description").fill_in("a long_description")
      form.field("badge_grouping_id").select(BadgeGrouping::GettingStarted)
      form.field("allow_title").toggle
      form.field("multiple_grant").toggle
      form.field("listable").toggle
      form.field("show_posts").toggle
      form.submit

      expect(PageObjects::Components::Toasts.new).to have_success(I18n.t("js.saved"))
      expect(badges_page).to have_badge("a name")
    end
  end

  context "with enable_badge_sql" do
    before { SiteSetting.enable_badge_sql = true }

    it "shows the sql section" do
      badges_page.new_page

      form.field("query").fill_in("a query")

      expect(form.field("auto_revoke")).to be_unchecked
      expect(form.field("target_posts")).to be_unchecked
    end
  end
end
