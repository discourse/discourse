# frozen_string_literal: true

describe "Admin Badges Page", type: :system do
  before { SiteSetting.enable_badges = true }

  fab!(:current_user) { Fabricate(:admin) }

  let(:badges_page) { PageObjects::Pages::AdminBadges.new }

  before { sign_in(current_user) }

  context "with system badge" do
    it "displays badge" do
      badges_page.visit_page(Badge::Autobiographer)

      badge = Badge.find(Badge::Autobiographer)
      form = badges_page.form

      expect(form.field("enabled")).to be_enabled
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
      expect(form.field("icon")).to have_value("user-pen")
      expect(form.container("name")).to have_content(badge.name.strip)
      expect(form.container("description")).to have_content(badge.description.strip)
      expect(form.container("long_description")).to have_content(badge.long_description.strip)
    end
  end

  context "when creating a badge" do
    it "creates a badge" do
      badges_page.new_page
      badges_page.form.field("enabled").accept
      badges_page.form.field("name").fill_in("a name")
      badges_page.form.field("badge_type_id").select(BadgeType::Bronze)
      badges_page.form.field("icon").select("truck-medical")
      badges_page.form.field("description").fill_in("a description")
      badges_page.form.field("long_description").fill_in("a long_description")
      badges_page.form.field("badge_grouping_id").select(BadgeGrouping::GettingStarted)
      badges_page.form.field("allow_title").toggle
      badges_page.form.field("multiple_grant").toggle
      badges_page.form.field("listable").toggle
      badges_page.form.field("show_posts").toggle
      badges_page.submit_form

      expect(badges_page).to have_saved_form
      expect(badges_page).to have_badge("a name")
    end
  end

  context "when updating a badge" do
    it "can upload an image for the badge" do
      badges_page.visit_page(Badge::Autobiographer).upload_image("logo.jpg").submit_form

      expect(badges_page).to have_saved_form

      badge = Badge.find(Badge::Autobiographer)
      try_until_success do
        expect(badge.image_upload_id).to be_present
        expect(badge.icon).to be_blank
      end
    end

    it "can change to an icon for the badge" do
      badge = Badge.find(Badge::Autobiographer)
      badge.update!(image_upload_id: Fabricate(:image_upload).id)

      badges_page.visit_page(Badge::Autobiographer).choose_icon("truck-medical").submit_form

      expect(badges_page).to have_saved_form
      expect(badge.reload.image_upload_id).to be_blank
      expect(badge.icon).to eq("truck-medical")
    end
  end

  context "with enable_badge_sql" do
    before { SiteSetting.enable_badge_sql = true }

    it "shows the sql section" do
      badges_page.new_page.fill_query("a query")

      expect(badges_page.form.field("auto_revoke")).to be_unchecked
      expect(badges_page.form.field("target_posts")).to be_unchecked
    end

    context "when trigger is 0" do
      fab!(:badge) do
        Fabricate(:badge, enabled: true, icon: "trick-medial", query: "a query", trigger: 0)
      end

      it "doesn't override the trigger value" do
        badges_page.visit_page(badge.id)

        expect(badges_page.form.field("trigger").value).to eq("0")
      end
    end
  end

  context "when deleting a badge" do
    let(:dialog) { PageObjects::Components::Dialog.new }

    it "deletes a badge" do
      badges_page.new_page
      badges_page.form.field("enabled").accept
      badges_page.form.field("name").fill_in("a name")
      badges_page.form.field("badge_type_id").select(BadgeType::Bronze)
      badges_page.form.field("icon").select("truck-medical")
      badges_page.submit_form
      expect(badges_page).to have_saved_form
      badges_page.form.field("name").fill_in("another name")
      badges_page.delete_badge
      dialog.click_yes

      expect(page).to have_current_path("/admin/badges")
    end
  end
end
