# frozen_string_literal: true

describe "Composer tags with the new select controls" do
  with_select_controls(true)

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:category)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:drafts_menu) { PageObjects::Components::DraftsMenu.new }
  let(:tag_chooser) { PageObjects::Components::UiKit::DSelect.at("#{chooser_selector}.d-select") }
  let(:legacy_tag_chooser) do
    PageObjects::Components::SelectKit.new("#{chooser_selector}.select-kit")
  end

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    category.set_permissions(everyone: :full)
    category.save!
  end

  def chooser_selector
    "#reply-control .tags-input .mini-tag-chooser"
  end

  def open_new_topic(as:, title: "Topic created with the new tag chooser")
    sign_in(as)
    visit "/new-topic"
    expect(composer).to be_opened
    composer.fill_title(title)
    composer.fill_content("This is the body of a topic with tags")
    composer.switch_category(category.name)
  end

  def have_chip(name)
    have_css("#{chooser_selector} .d-select__chip", text: name)
  end

  def have_legacy_selection(*names)
    have_css("#{chooser_selector}.select-kit .formatted-selection", exact_text: names.join(", "))
  end

  def type_new_tag(name)
    tag_chooser.search(name)
    expect(tag_chooser).to have_option_value("tag-name:#{name}")
    tag_chooser.press_in_controller(:enter)
    expect(page).to have_chip(name)
  end

  def pick_create_row(name)
    tag_chooser.search(name)
    tag_chooser.select_value("tag-name:#{name}")
    expect(page).to have_chip(name)
  end

  def paste_into_tag_input(text)
    tag_chooser.open
    page.execute_script(<<~JS, tag_chooser.input, text)
      const [input, text] = arguments;
      const data = new DataTransfer();
      data.setData("text/plain", text);
      input.dispatchEvent(
        new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true })
      );
    JS
  end

  def save_draft_and_close
    composer.close
    expect(toasts).to have_success(I18n.t("js.composer.draft_saved"))
  end

  def resume_draft
    visit "/"
    drafts_menu.open
    drafts_menu.resume_draft
    expect(composer).to be_opened
  end

  it "attaches an existing tag picked in the new tag chooser to the created topic" do
    open_new_topic(as: user)

    tag_chooser.select_name(tag.name)
    expect(page).to have_chip(tag.name)
    tag_chooser.close

    composer.create

    expect(topic_page).to have_topic_title("Topic created with the new tag chooser")
    expect(topic_page.topic_tags).to eq([tag.name])
  end

  it "attaches a numeric-name tag by name in the new tag chooser when its name matches another tag's id" do
    other_tag = Fabricate(:tag, name: "other-tag")
    numeric_tag = Fabricate(:tag, name: other_tag.id.to_s)

    open_new_topic(as: user)

    tag_chooser.search(numeric_tag.name)
    tag_chooser.select_value(numeric_tag.id)
    expect(page).to have_chip(numeric_tag.name)
    tag_chooser.close

    composer.create

    expect(topic_page).to have_topic_title("Topic created with the new tag chooser")
    expect(topic_page.topic_tags).to eq([numeric_tag.name])
    expect(Topic.last.tags).to contain_exactly(numeric_tag)
  end

  it "creates a tag typed into the new tag chooser and confirmed with Enter" do
    SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

    open_new_topic(as: user)

    type_new_tag("brand-new-tag")
    tag_chooser.close

    composer.create

    expect(topic_page).to have_topic_title("Topic created with the new tag chooser")
    expect(topic_page.topic_tags).to eq(["brand-new-tag"])
    expect(Tag.exists?(name: "brand-new-tag")).to eq(true)
  end

  it "adds every pipe-separated name pasted into the new tag chooser" do
    open_new_topic(as: admin)

    paste_into_tag_input("alpha|beta|gamma")

    expect(page).to have_chip("alpha")
    expect(page).to have_chip("beta")
    expect(page).to have_chip("gamma")
  end

  it "resumes a draft saved from the new tag chooser in the legacy chooser with all its tags" do
    other_tag = Fabricate(:tag, name: "other-tag")

    open_new_topic(as: admin)

    tag_chooser.select_name(tag.name)
    tag_chooser.select_name(other_tag.name)
    tag_chooser.close
    pick_create_row("draft-new-one")
    pick_create_row("draft-new-two")
    tag_chooser.close
    save_draft_and_close

    SiteSetting.enable_new_select_controls = false
    resume_draft

    expect(page).to have_legacy_selection(
      tag.name,
      other_tag.name,
      "draft-new-one",
      "draft-new-two",
    )

    composer.create

    expect(topic_page).to have_topic_title("Topic created with the new tag chooser")
    expect(topic_page.topic_tags).to contain_exactly(
      tag.name,
      other_tag.name,
      "draft-new-one",
      "draft-new-two",
    )
  end

  it "resumes a draft saved from the legacy chooser in the new tag chooser with all its tags" do
    other_tag = Fabricate(:tag, name: "other-tag")
    SiteSetting.enable_new_select_controls = false

    open_new_topic(as: admin)

    legacy_tag_chooser.expand
    [tag.name, other_tag.name].each do |name|
      legacy_tag_chooser.search(name)
      legacy_tag_chooser.select_row_by_name(name)
    end
    %w[draft-new-one draft-new-two].each do |name|
      legacy_tag_chooser.search(name)
      legacy_tag_chooser.select_row_by_value(name)
    end
    legacy_tag_chooser.collapse
    save_draft_and_close

    SiteSetting.enable_new_select_controls = true
    resume_draft

    expect(page).to have_chip(tag.name)
    expect(page).to have_chip(other_tag.name)
    expect(page).to have_chip("draft-new-one")
    expect(page).to have_chip("draft-new-two")

    composer.create

    expect(topic_page).to have_topic_title("Topic created with the new tag chooser")
    expect(topic_page.topic_tags).to contain_exactly(
      tag.name,
      other_tag.name,
      "draft-new-one",
      "draft-new-two",
    )
  end

  it "blocks a topic without tags in a category requiring one until a tag is added in the new tag chooser" do
    category.update!(minimum_required_tags: 1)

    open_new_topic(as: user)
    composer.create

    expect(page).to have_css(
      "#reply-control .tags-input .popup-tip.bad",
      text: I18n.t("js.composer.error.tags_missing", count: 1),
    )
    expect(composer).to be_opened

    tag_chooser.select_name(tag.name)
    tag_chooser.close
    composer.create

    expect(topic_page).to have_topic_title("Topic created with the new tag chooser")
    expect(topic_page.topic_tags).to eq([tag.name])
  end

  it "refetches the new tag chooser's options when the category changes while it is closed" do
    tag_a = Fabricate(:tag, name: "only-in-a")
    tag_b = Fabricate(:tag, name: "only-in-b")
    category_a = Fabricate(:category, name: "Category A")
    category_b = Fabricate(:category, name: "Category B")
    category_a.update!(allowed_tags: [tag_a.name])
    category_b.update!(allowed_tags: [tag_b.name])

    sign_in(user)
    visit "/new-topic"
    expect(composer).to be_opened

    composer.switch_category(category_a.name)
    tag_chooser.open
    expect(tag_chooser).to have_option_name(tag_a.name)
    expect(tag_chooser).to have_no_option_name(tag_b.name)
    tag_chooser.close

    composer.switch_category(category_b.name)
    tag_chooser.open
    expect(tag_chooser).to have_option_name(tag_b.name)
    expect(tag_chooser).to have_no_option_name(tag_a.name)
  end

  it "disables a one-per-topic sibling in the new tag chooser when editing a topic" do
    todo_tag = Fabricate(:tag, name: "todo")
    ready_tag = Fabricate(:tag, name: "ready-to-deploy")
    Fabricate(:tag_group, name: "Workflow", tags: [todo_tag, ready_tag], one_per_topic: true)
    topic = Fabricate(:topic, user: admin, tags: [todo_tag])
    post = Fabricate(:post, topic:, user: admin)

    sign_in(admin)
    visit topic.url
    topic_page.click_post_action_button(post, :edit)
    expect(composer).to be_opened

    tag_chooser.search(ready_tag.name)

    expect(tag_chooser).to have_disabled_option(ready_tag.id)
  end

  it "adds a tag to an existing topic from the new tag chooser in the title editor" do
    other_tag = Fabricate(:tag, name: "other-tag")
    topic = Fabricate(:topic, user: admin, tags: [tag])
    Fabricate(:post, topic:, user: admin)
    edit_tag_chooser =
      PageObjects::Components::UiKit::DSelect.at("#topic-title .mini-tag-chooser.d-select")

    sign_in(admin)
    topic_page.visit_topic(topic)
    topic_page.click_topic_edit_title

    edit_tag_chooser.select_name(other_tag.name)
    expect(page).to have_css("#topic-title .mini-tag-chooser .d-select__chip", text: other_tag.name)
    edit_tag_chooser.close
    topic_page.click_topic_title_submit_edit

    expect(page).to have_no_css("#topic-title .submit-edit")
    expect(topic_page.topic_tags).to contain_exactly(tag.name, other_tag.name)
    expect(topic.reload.tags).to contain_exactly(tag, other_tag)
  end
end
