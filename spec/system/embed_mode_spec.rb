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

  it "shows 'be the first to reply' message for topic with no replies" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css(".embed-topic-footer__first-reply")
  end

  it "shows powered by discourse badge" do
    SiteSetting.enable_powered_by_discourse = true
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css(".embed-topic-footer .powered-by-discourse")
  end

  it "does not show powered by discourse badge when setting is disabled" do
    SiteSetting.enable_powered_by_discourse = false
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_no_css(".embed-topic-footer .powered-by-discourse")
  end

  it "does not show embed footer without embed mode" do
    visit("/t/#{topic.slug}/#{topic.id}")

    expect(page).to have_no_css(".embed-topic-footer")
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

      it "auto-opens the composer" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(page).to have_css("#reply-control.open")
      end

      it "uses the rich text editor" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(page).to have_css("#reply-control.open")
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

      it "opens the composer when clicking reply" do
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
        topic_page.click_reply_button

        expect(page).to have_css("#reply-control.open")
      end

      it "does not show 'be the first to reply' message" do
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

        expect(page).to have_no_css(".embed-topic-footer__first-reply")
      end

      it "still shows powered by discourse badge" do
        SiteSetting.enable_powered_by_discourse = true
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

        expect(page).to have_css(".embed-topic-footer .powered-by-discourse")
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
