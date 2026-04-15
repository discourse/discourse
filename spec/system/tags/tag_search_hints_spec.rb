# frozen_string_literal: true

describe "Tag search hints in composer" do
  fab!(:admin)

  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  context "with one_per_topic tag group" do
    fab!(:todo_tag) { Fabricate(:tag, name: "todo") }
    fab!(:ready_tag) { Fabricate(:tag, name: "ready-to-deploy") }

    fab!(:tag_group) do
      Fabricate(:tag_group, name: "Workflow", tags: [todo_tag, ready_tag], one_per_topic: true)
    end

    fab!(:topic) { Fabricate(:topic, user: admin, tags: [todo_tag]) }
    fab!(:post) { Fabricate(:post, topic: topic, user: admin) }

    it "shows sibling tag as disabled with tooltip" do
      sign_in(admin)
      visit topic.url

      find("#post_1 .post-controls .edit").click
      expect(composer).to be_opened

      tag_chooser = PageObjects::Components::SelectKit.new(".composer-fields .mini-tag-chooser")
      tag_chooser.expand
      tag_chooser.search("ready-to-deploy")

      expect(page).to have_css(
        ".mini-tag-chooser .select-kit-row.disabled[data-name='ready-to-deploy']",
      )
    end
  end

  context "with parent tag group" do
    fab!(:parent_tag) { Fabricate(:tag, name: "vehicles") }
    fab!(:child_tag) { Fabricate(:tag, name: "sedan") }

    fab!(:tag_group) do
      Fabricate(:tag_group, name: "Vehicle Types", tags: [child_tag], parent_tag: parent_tag)
    end

    it "shows child tag as disabled when parent is not selected" do
      sign_in(admin)
      visit "/new-topic"
      expect(composer).to be_opened

      tag_chooser = PageObjects::Components::SelectKit.new(".composer-fields .mini-tag-chooser")
      tag_chooser.expand
      tag_chooser.search("sedan")

      expect(page).to have_css(".mini-tag-chooser .select-kit-row.disabled[data-name='sedan']")
    end
  end
end
