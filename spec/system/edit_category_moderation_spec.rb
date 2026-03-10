# frozen_string_literal: true

describe "Edit Category Moderation", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }

  describe "approval type UI controls" do
    before { sign_in(admin) }

    it "shows approval type dropdowns on the moderation tab" do
      category_page.visit_moderation(category)

      expect(page).to have_css(".topic-approval-type select")
      expect(page).to have_css(".reply-approval-type select")
    end

    it "shows GroupChooser when except_groups is selected" do
      category_page.visit_moderation(category)
      category_page.select_topic_approval_type("except_groups")

      expect(page).to have_css(".topic-approval-groups .group-chooser")
    end

    it "shows GroupChooser when only_groups is selected" do
      category_page.visit_moderation(category)
      category_page.select_topic_approval_type("only_groups")

      expect(page).to have_css(".topic-approval-groups .group-chooser")
    end

    it "hides GroupChooser when none is selected" do
      category_page.visit_moderation(category)
      category_page.select_topic_approval_type("none")

      expect(page).to have_no_css(".topic-approval-groups .group-chooser")
    end

    it "shows validation error when groups required but none selected" do
      category_page.visit_moderation(category)
      category_page.select_topic_approval_type("except_groups")
      category_page.save_settings

      expect(category_page).to have_topic_approval_groups_error
    end

    it "saves approval type and groups successfully" do
      category_page.visit_moderation(category)
      category_page.select_topic_approval_type("except_groups")
      category_page.select_topic_approval_groups(group.name)
      category_page.save_settings

      expect(category.reload.topic_approval_type).to eq("except_groups")
      expect(category.reload.topic_approval_groups.map(&:group_id)).to contain_exactly(group.id)
    end
  end

  shared_examples "group-based topic approval" do |approval_type|
    fab!(:regular_user, :user)

    before do
      category.category_setting.update!(topic_approval_type: approval_type)
      Fabricate(:category_approval_group, category: category, group: group, approval_type: "topic")
    end

    it "routes posts from non-group members through the review queue" do
      sign_in(regular_user)
      visit "/c/#{category.slug}"

      find("#create-topic").click
      composer.fill_title("Approval test topic")
      composer.fill_content("This post needs approval")
      composer.create

      expect(page).to have_css(".d-modal", text: /queued|approval/i).or have_current_path(
             %r{/review},
           )
    end

    it "allows group members to post without approval" do
      Fabricate(:group_user, group: group, user: regular_user)
      sign_in(regular_user)
      visit "/c/#{category.slug}"

      find("#create-topic").click
      composer.fill_title("Allowed topic")
      composer.fill_content("This post bypasses approval")
      composer.create

      expect(page).to have_css("#topic-title", text: "Allowed topic")
    end
  end

  describe "only_groups approval (type 3)" do
    include_examples "group-based topic approval", :only_groups
  end

  describe "except_groups approval (type 2)" do
    include_examples "group-based topic approval", :except_groups
  end
end
