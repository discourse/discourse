# frozen_string_literal: true

RSpec.describe "Post Voting Category Settings" do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.post_voting_enabled = true
    sign_in(admin)
  end

  it "can toggle post voting custom fields via FormKit" do
    category_page.visit_settings(category)

    form.field("custom_fields.create_as_post_voting_default").toggle
    form.field("custom_fields.only_post_voting_in_this_category").toggle
    banner.click_save

    expect(toasts).to have_success(I18n.t("js.saved"))
    category.reload
    expect(category.custom_fields["create_as_post_voting_default"]).to eq(true)
    expect(category.custom_fields["only_post_voting_in_this_category"]).to eq(true)
  end

  it "hides the category setting when every category allows post voting" do
    category_page.visit_settings(category)

    expect(form).to have_no_field_with_name("custom_fields.allow_post_voting")
  end

  it "lets a moderator who manages categories change the category setting" do
    SiteSetting.moderators_manage_categories = true
    SiteSetting.post_voting_category_mode = "opt_in"
    sign_in(Fabricate(:moderator))

    category_page.visit_settings(category)
    form.field("custom_fields.allow_post_voting").toggle
    banner.click_save

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
  end

  context "when post voting is opt in" do
    before { SiteSetting.post_voting_category_mode = "opt_in" }

    it "starts unchecked and opts the category in" do
      category_page.visit_settings(category)

      expect(form.field("custom_fields.allow_post_voting").value).to eq(false)

      form.field("custom_fields.allow_post_voting").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(category.reload.custom_fields[PostVoting::ALLOW_POST_VOTING]).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
    end

    it "reveals the dependent settings as soon as the category opts in" do
      category_page.visit_settings(category)

      expect(form).to have_no_field_with_name("custom_fields.create_as_post_voting_default")
      expect(form).to have_no_field_with_name("custom_fields.only_post_voting_in_this_category")

      form.field("custom_fields.allow_post_voting").toggle

      expect(form).to have_field_with_name("custom_fields.create_as_post_voting_default")
      expect(form).to have_field_with_name("custom_fields.only_post_voting_in_this_category")

      form.field("custom_fields.create_as_post_voting_default").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(category.reload.custom_fields["create_as_post_voting_default"]).to eq(true)
    end
  end

  context "when the category has subcategories" do
    fab!(:subcategory) { Fabricate(:category, parent_category: category) }

    before { SiteSetting.post_voting_category_mode = "opt_in" }

    it "copies the category's value to its subcategories when the prompt is accepted" do
      category_page.visit_settings(category)

      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_yes
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(true)
    end

    it "leaves subcategories alone when the prompt is declined" do
      category_page.visit_settings(category)

      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_no
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(false)
    end

    it "does not propagate again on the next save" do
      category_page.visit_settings(category)
      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_yes
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))

      subcategory.upsert_custom_fields(PostVoting::ALLOW_POST_VOTING => false)
      PostVoting.clear_category_overrides_cache(after_commit: false)

      category_page.visit_settings(category)
      form.field("custom_fields.create_as_post_voting_default").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(false)
    end

    it "shows a pending note until the change is saved" do
      pending_note = I18n.t("js.category.post_voting_subcategories.pending", count: 1)
      field = "[data-name='custom_fields.allow_post_voting']"

      category_page.visit_settings(category)

      expect(page).to have_no_css(field, text: pending_note)

      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_yes

      expect(page).to have_css(field, text: pending_note)

      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(page).to have_no_css(field, text: pending_note)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(true)
    end

    it "shows no pending note when the prompt is declined" do
      pending_note = I18n.t("js.category.post_voting_subcategories.pending", count: 1)

      category_page.visit_settings(category)
      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_no

      expect(page).to have_no_css(
        "[data-name='custom_fields.allow_post_voting']",
        text: pending_note,
      )
    end

    it "does not ask again when the checkbox is put back before saving" do
      pending_note = I18n.t("js.category.post_voting_subcategories.pending", count: 1)
      field = "[data-name='custom_fields.allow_post_voting']"

      category_page.visit_settings(category)

      form.field("custom_fields.allow_post_voting").toggle

      expect(dialog).to have_content(
        I18n.t("js.category.post_voting_subcategories.enable", count: 1),
      )

      dialog.click_yes

      expect(page).to have_css(field, text: pending_note)

      form.field("custom_fields.allow_post_voting").toggle

      expect(dialog).to be_closed
      expect(page).to have_no_css(field, text: pending_note)

      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(false)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(false)
    end

    it "asks again when the checkbox is changed back and then changed once more" do
      category_page.visit_settings(category)

      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_no

      form.field("custom_fields.allow_post_voting").toggle

      expect(dialog).to be_closed

      form.field("custom_fields.allow_post_voting").toggle

      expect(dialog).to have_content(
        I18n.t("js.category.post_voting_subcategories.enable", count: 1),
      )

      dialog.click_yes
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(true)
    end

    it "asks with the disable wording for a category that already allows post voting" do
      category.upsert_custom_fields(PostVoting::ALLOW_POST_VOTING => true)
      PostVoting.clear_category_overrides_cache(after_commit: false)

      category_page.visit_settings(category)
      form.field("custom_fields.allow_post_voting").toggle

      expect(dialog).to have_content(
        I18n.t("js.category.post_voting_subcategories.disable", count: 1),
      )

      dialog.click_no

      form.field("custom_fields.allow_post_voting").toggle

      expect(dialog).to be_closed
    end

    it "propagates a disallowed value too" do
      subcategory.upsert_custom_fields(PostVoting::ALLOW_POST_VOTING => true)
      category.upsert_custom_fields(PostVoting::ALLOW_POST_VOTING => true)
      PostVoting.clear_category_overrides_cache(after_commit: false)

      category_page.visit_settings(category)
      form.field("custom_fields.allow_post_voting").toggle
      dialog.click_yes
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(PostVoting.post_voting_enabled_for?(subcategory.id)).to eq(false)
    end
  end

  it "does not prompt for a category without subcategories" do
    SiteSetting.post_voting_category_mode = "opt_in"

    category_page.visit_settings(category)
    form.field("custom_fields.allow_post_voting").toggle

    expect(dialog).to be_closed

    banner.click_save

    expect(toasts).to have_success(I18n.t("js.saved"))
    expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
  end

  context "when post voting is opt out" do
    before { SiteSetting.post_voting_category_mode = "opt_out" }

    it "starts checked and opts the category out" do
      category_page.visit_settings(category)

      expect(form.field("custom_fields.allow_post_voting").value).to eq(true)

      form.field("custom_fields.allow_post_voting").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(category.reload.custom_fields[PostVoting::ALLOW_POST_VOTING]).to eq(false)
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(false)
    end

    it "hides the dependent settings as soon as the category opts out" do
      category_page.visit_settings(category)

      expect(form).to have_field_with_name("custom_fields.create_as_post_voting_default")

      form.field("custom_fields.allow_post_voting").toggle

      expect(form).to have_no_field_with_name("custom_fields.create_as_post_voting_default")
      expect(form).to have_no_field_with_name("custom_fields.only_post_voting_in_this_category")
    end

    it "leaves the category allowed when unrelated settings are saved" do
      category_page.visit_settings(category)

      form.field("custom_fields.create_as_post_voting_default").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      expect(category.reload.custom_fields[PostVoting::ALLOW_POST_VOTING]).to eq(true)
      expect(PostVoting.post_voting_enabled_for?(category.id)).to eq(true)
    end
  end
end
