# frozen_string_literal: true

describe "Embed mode" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { SiteSetting.embed_full_app = true }

  it "applies embed-mode class to body when embed_mode=true" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
  end

  it "does not apply embed-mode class without the param" do
    visit("/t/#{topic.slug}/#{topic.id}")

    expect(page).to have_no_css("body.embed-mode")
  end

  it "hides suggested topics in embed mode" do
    Fabricate(:post) # create another topic for suggestions
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
    expect(page).to have_no_css(".suggested-topics")
  end

  it "loads topic content without JS errors" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
    expect(topic_page).to have_topic_title(topic.title)
    expect(page).to have_css("#post_1")
  end

  context "when logged in" do
    fab!(:user)
    let(:composer) { PageObjects::Components::Composer.new }

    before do
      SiteSetting.rich_editor = true
      sign_in(user)
    end

    context "with a topic that has no replies" do
      fab!(:no_reply_topic, :topic)
      fab!(:no_reply_post) { Fabricate(:post, topic: no_reply_topic) }

      it "auto-opens the composer in fullscreen" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(page).to have_css("#reply-control.fullscreen")
      end

      it "uses the rich text editor" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(page).to have_css("#reply-control.fullscreen")
        expect(composer).to have_rich_editor
      end

      it "does not auto-open the composer outside embed mode" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}")

        expect(page).to have_no_css("#reply-control.open")
        expect(page).to have_no_css("#reply-control.fullscreen")
      end
    end

    context "with a topic that has replies" do
      fab!(:reply) { Fabricate(:post, topic: topic) }

      it "does not auto-open the composer" do
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

        expect(page).to have_no_css("#reply-control.open")
        expect(page).to have_no_css("#reply-control.fullscreen")
      end

      it "opens the composer in fullscreen when clicking reply" do
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
        find("#topic-footer-buttons .btn-primary.create").click

        expect(page).to have_css("#reply-control.fullscreen")
      end
    end
  end

  context "when not logged in" do
    fab!(:no_reply_topic, :topic)
    fab!(:no_reply_post) { Fabricate(:post, topic: no_reply_topic) }

    it "does not auto-open the composer" do
      visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

      expect(page).to have_no_css("#reply-control.open")
      expect(page).to have_no_css("#reply-control.fullscreen")
    end
  end
end
