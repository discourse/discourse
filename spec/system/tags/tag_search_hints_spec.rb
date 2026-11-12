# frozen_string_literal: true

describe "Tag search: disabled hints" do
  fab!(:admin)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer_tag_chooser) do
    PageObjects::Components::SelectKit.new(".composer-fields .mini-tag-chooser")
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def open_topic_for_edit(topic, post)
    sign_in(admin)
    visit topic.url
    topic_page.click_post_action_button(post, :edit)
    expect(composer).to be_opened
  end

  describe "in the composer (mini-tag-chooser)" do
    context "with a one_per_topic tag group" do
      fab!(:todo_tag) { Fabricate(:tag, name: "todo") }
      fab!(:ready_tag) { Fabricate(:tag, name: "ready-to-deploy") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Workflow", tags: [todo_tag, ready_tag], one_per_topic: true)
      end
      fab!(:topic) { Fabricate(:topic, user: admin, tags: [todo_tag]) }
      fab!(:post) { Fabricate(:post, topic:, user: admin) }

      it "marks the sibling tag as disabled" do
        open_topic_for_edit(topic, post)
        composer_tag_chooser.expand
        composer_tag_chooser.search("ready-to-deploy")

        expect(composer_tag_chooser).to have_disabled_row_name("ready-to-deploy")
      end

      context "with tags_sort_alphabetically enabled" do
        fab!(:usable_tag) { Fabricate(:tag, name: "z-ready") }

        before { SiteSetting.tags_sort_alphabetically = true }

        it "lists usable tags before disabled tags" do
          open_topic_for_edit(topic, post)
          composer_tag_chooser.expand
          composer_tag_chooser.search("ready")

          expect(composer_tag_chooser).to have_disabled_row_name("ready-to-deploy")

          names = composer_tag_chooser.option_names
          expect(names.index("z-ready")).to be < names.index("ready-to-deploy")
        end
      end
    end

    context "with a missing parent tag" do
      fab!(:parent_tag) { Fabricate(:tag, name: "vehicles") }
      fab!(:child_tag) { Fabricate(:tag, name: "sedan") }
      fab!(:tag_group) do
        Fabricate(:tag_group, name: "Vehicle Types", tags: [child_tag], parent_tag:)
      end

      it "marks the child tag as disabled" do
        sign_in(admin)
        visit "/new-topic"
        expect(composer).to be_opened

        composer_tag_chooser.expand
        composer_tag_chooser.search("sedan")

        expect(composer_tag_chooser).to have_disabled_row_name("sedan")
      end
    end

    context "with a synonym tag" do
      fab!(:apple_tag) { Fabricate(:tag, name: "apple-inc") }
      fab!(:aapl_tag) { Fabricate(:tag, name: "aapl", target_tag: apple_tag) }

      it "shows the synonym as selectable with a hint pointing to the target tag" do
        sign_in(admin)
        visit "/new-topic"
        expect(composer).to be_opened

        composer_tag_chooser.expand
        composer_tag_chooser.search("aapl")

        expect(composer_tag_chooser).to have_no_disabled_row_name("aapl")
        expect(composer_tag_chooser).to have_row_synonym_hint("aapl", "→ apple-inc")
      end
    end
  end

  describe "in bulk-actions (tag-chooser)" do
    fab!(:parent_tag) { Fabricate(:tag, name: "vehicles") }
    fab!(:child_tag) { Fabricate(:tag, name: "sedan") }
    fab!(:tag_group) do
      Fabricate(:tag_group, name: "Vehicle Types", tags: [child_tag], parent_tag:)
    end
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic:) }

    let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
    let(:topic_list) { PageObjects::Components::TopicList.new }
    let(:bulk_modal) { PageObjects::Modals::ManageTags.new }

    it "shows disabled rows with a visible reason" do
      sign_in(admin)
      visit "/latest"
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topic)
      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_bulk_button("manage-tags")
      expect(bulk_modal).to be_open

      chooser = bulk_modal.add_tag_selector
      chooser.expand
      chooser.search("sedan")

      expect(chooser).to have_disabled_row_name("sedan")
      expect(chooser).to have_disabled_row_reason("sedan")
    end
  end
end
