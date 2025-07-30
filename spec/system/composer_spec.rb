# frozen_string_literal: true

describe "Composer", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(user) }
  before { SiteSetting.floatkit_autocomplete_composer = false }

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

  context "with floatkit autocomplete enabled" do
    before { SiteSetting.floatkit_autocomplete_composer = true }

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
  end
end
