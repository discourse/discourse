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

  it "shows the topic navigation widget" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css(".topic-navigation")
  end

  it "loads topic content without JS errors" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css("body.embed-mode")
    expect(page).to have_css("#topic-title .fancy-title", text: topic.title, visible: :all)
    expect(page).to have_css("#post_1")
  end

  it "shows 'be the first to reply' message for topic with no replies" do
    visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

    expect(page).to have_css(".embed-topic-footer__first-reply")
    expect(page).to have_css(".embed-topic-footer__first-reply .btn-primary")
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
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    before do
      SiteSetting.rich_editor = true
      sign_in(user)
    end

    context "with a topic that has no replies" do
      fab!(:no_reply_topic, :topic)
      fab!(:no_reply_post) { Fabricate(:post, topic: no_reply_topic) }

      it "shows the docked composer" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(topic_page).to have_docked_composer
      end

      it "does not show the docked composer outside embed mode" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}")

        expect(topic_page).to have_no_docked_composer
      end

      it "does not show floating timeline button" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(topic_page).to have_no_floating_timeline_button
      end

      it "hides the standard composer" do
        visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

        expect(page).to have_no_css("#reply-control.open")
      end
    end

    context "with a topic that has replies" do
      fab!(:reply) { Fabricate(:post, topic: topic) }

      it "shows the docked composer" do
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

        expect(topic_page).to have_docked_composer
      end

      it "focuses the docked composer when clicking reply" do
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
        topic_page.click_embed_reply_button

        expect(page).to have_css(".embed-mode-composer .d-editor-input:focus")
      end

      it "submits a reply through the docked composer" do
        user.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
        visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")

        expect(topic_page).to have_docked_composer

        find(".embed-mode-composer .d-editor-input").fill_in(with: "Hello from the docked composer")
        find(".embed-mode-composer .docked-composer__submit-btn").click

        expect(page).to have_css(".topic-post", text: "Hello from the docked composer")
      end

      context "with many replies" do
        before { 15.times { Fabricate(:post, topic: topic) } }

        it "shows floating timeline button when footer is not visible" do
          visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          expect(topic_page).to have_post_number(2)

          expect(topic_page).to have_floating_timeline_button
          expect(topic_page).to have_no_floating_reply_button
        end

        it "opens the timeline when clicking the floating timeline button" do
          visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          expect(topic_page).to have_post_number(2)

          topic_page.click_floating_timeline_button
          expect(page).to have_css(".timeline-fullscreen.show")
        end

        it "shows the topic progress bar at the bottom (not sticky)" do
          visit("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          expect(topic_page).to have_post_number(2)

          expect(page).to have_css("#topic-progress-wrapper", visible: :visible)
          expect(page).to have_css(".topic-navigation.with-topic-progress", visible: :visible)
        end
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

    it "does not show the docked composer" do
      visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

      expect(topic_page).to have_no_docked_composer
    end

    it "shows login label on the embed first-reply footer" do
      visit("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")

      expect(page).to have_button(I18n.t("js.topic.login_reply"))
    end
  end
end
