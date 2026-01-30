# frozen_string_literal: true

describe "Composer", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(user) }

  it "displays user cards in preview" do
    page.visit "/new-topic"

    expect(composer).to be_opened

    composer.fill_content("@#{user.username}")
    composer.preview.find("a.mention").click

    page.has_css?("#user-card")
  end

  context "in a topic, the autocomplete prioritizes" do
    fab!(:topic_user, :user)
    fab!(:second_reply_user, :user)

    fab!(:topic) { Fabricate(:topic, user: topic_user) }
    fab!(:op) { Fabricate(:post, topic: topic, user: topic_user) }
    let!(:op_post) { PageObjects::Components::Post.new(op.post_number) }

    fab!(:second_reply) { Fabricate(:post, topic: topic, user: second_reply_user) }
    let!(:second_reply_post) { PageObjects::Components::Post.new(second_reply.post_number) }

    before { SiteSetting.enable_names = false }

    it "the topic owner if replying to topic" do
      page.visit "/t/#{topic.id}"

      op_post.reply
      expect(composer).to be_opened
      composer.type_content("@")

      expect(composer.mention_menu_autocomplete_username_list).to eq(
        [op.username, second_reply_user.username], # must be first the topic owner
      )
    end

    it "the recipient of the reply when replying" do
      page.visit "/t/#{topic.id}"

      second_reply_post.reply
      expect(composer).to be_opened
      composer.type_content("@")

      expect(composer.mention_menu_autocomplete_username_list).to eq(
        [second_reply_user.username, topic_user.username], # must be first the reply user
      )
    end

    it "the recipient of the reply when editing a reply" do
      admin = Fabricate(:admin, refresh_auto_groups: true)
      reply_to_second_post =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: second_reply.post_number)
      reply_post = PageObjects::Components::Post.new(reply_to_second_post.post_number)

      sign_in(admin)
      page.visit "/t/#{topic.id}"
      reply_post.edit

      expect(composer).to be_opened

      composer.type_content(" @")

      expect(composer.mention_menu_autocomplete_username_list).to eq(
        [second_reply_user.username, user.username, topic_user.username],
      )
    end
  end

  it "focuses the reply button when tabbing out of both editor modes" do
    page.visit "/new-topic"
    expect(composer).to be_opened
    composer.focus

    page.send_keys(:tab)

    expect(composer.reply_button_focused?).to eq(true)

    composer.toggle_rich_editor
    composer.focus

    page.send_keys(:tab)

    expect(composer.reply_button_focused?).to eq(true)
  end

  context "with tagging enabled" do
    fab!(:tag) { Fabricate(:tag, name: "test-tag") }
    fab!(:category)
    let(:mini_tag_chooser) { PageObjects::Components::SelectKit.new(".mini-tag-chooser") }
    let(:topic_page) { PageObjects::Pages::Topic.new }

    before do
      SiteSetting.tagging_enabled = true
      category.set_permissions(everyone: :full)
      category.save!
    end

    it "creates a topic with tags" do
      page.visit "/new-topic"
      expect(composer).to be_opened

      composer.fill_title("Test topic with tags")
      composer.fill_content("This is a test topic with tags")
      composer.switch_category(category.name)

      mini_tag_chooser.expand
      mini_tag_chooser.search(tag.name)
      mini_tag_chooser.select_row_by_name(tag.name)
      mini_tag_chooser.collapse

      composer.create

      expect(topic_page).to have_topic_title("Test topic with tags")
      expect(topic_page.topic_tags).to include(tag.name)
    end
  end
end
