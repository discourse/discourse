# frozen_string_literal: true

describe "Embed mode" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { SiteSetting.embed_full_app = true }

  it "applies embed-mode class to body when embed_mode=true" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator("body.embed-mode").filter(visible: true)).not_to have_count(0)
  end

  it "does not apply embed-mode class without the param" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator("body.embed-mode").filter(visible: true)).to have_count(0)
  end

  it "hides suggested topics in embed mode" do
    Fabricate(:post) # create another topic for suggestions
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator("body.embed-mode").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator(".suggested-topics").filter(visible: true)).to have_count(0)
  end

  it "shows the topic navigation widget" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".topic-navigation").filter(visible: true)).not_to have_count(0)
  end

  it "loads topic content without JS errors" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator("body.embed-mode").filter(visible: true)).not_to have_count(0)
    expect(browser_root.locator("#topic-title .fancy-title")).to contain_text(
      [browser_text_pattern(topic.title)],
      useInnerText: true,
    )
    expect(browser_root.locator("#post_1").filter(visible: true)).not_to have_count(0)
  end

  it "shows 'be the first to reply' message for topic with no replies" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".embed-topic-footer__first-reply").filter(visible: true),
    ).not_to have_count(0)
    expect(
      browser_root.locator(".embed-topic-footer__first-reply .btn-primary").filter(visible: true),
    ).not_to have_count(0)
  end

  it "shows powered by discourse badge" do
    SiteSetting.enable_powered_by_discourse = true
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".embed-topic-footer .powered-by-discourse").filter(visible: true),
    ).not_to have_count(0)
  end

  it "does not show powered by discourse badge when setting is disabled" do
    SiteSetting.enable_powered_by_discourse = false
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".embed-topic-footer .powered-by-discourse").filter(visible: true),
    ).to have_count(0)
  end

  it "does not show embed footer without embed mode" do
    browser_page
      .goto("/t/#{topic.slug}/#{topic.id}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(browser_root.locator(".embed-topic-footer").filter(visible: true)).to have_count(0)
  end

  context "when logged in" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    before { sign_in(user) }

    context "with a topic that has no replies" do
      fab!(:no_reply_topic, :topic)
      fab!(:no_reply_post) { Fabricate(:post, topic: no_reply_topic) }

      it "shows the docked composer" do
        browser_page
          .goto("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_page).to have_docked_composer
      end

      it "does not show the docked composer outside embed mode" do
        browser_page
          .goto("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_page).to have_no_docked_composer
      end

      it "does not show floating timeline button" do
        browser_page
          .goto("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_page).to have_no_floating_timeline_button
      end

      it "hides the standard composer" do
        browser_page
          .goto("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(browser_root.locator("#reply-control.open").filter(visible: true)).to have_count(0)
      end
    end

    context "with a topic that has replies" do
      fab!(:reply) { Fabricate(:post, topic: topic) }

      it "shows the docked composer" do
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_page).to have_docked_composer
      end

      it "focuses the docked composer when clicking reply" do
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        topic_page.click_embed_reply_button

        expect(
          browser_root.locator(".embed-mode-composer .d-editor-input:focus").filter(visible: true),
        ).not_to have_count(0)
      end

      it "submits a reply through the docked composer" do
        user.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(topic_page).to have_docked_composer

        browser_root
          .locator(".embed-mode-composer .d-editor-input")
          .filter(visible: true)
          .fill("Hello from the docked composer")
        browser_root
          .locator(".embed-mode-composer .docked-composer__submit-btn")
          .filter(visible: true)
          .click

        expect(browser_root.locator(".topic-post").filter(visible: true)).to contain_text(
          [browser_text_pattern("Hello from the docked composer")],
          useInnerText: true,
        )
      end

      it "edits a post through the docked composer" do
        own_post = Fabricate(:post, topic: topic, user: user, raw: "Original content")
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        browser_root
          .locator("#post_#{own_post.post_number} button.edit")
          .filter(visible: true)
          .click

        expect(
          browser_root.locator(".embed-mode-composer__editing").filter(visible: true),
        ).not_to have_count(0)
        expect(
          browser_root.locator("#reply-control.composer-action-edit").filter(visible: true),
        ).to have_count(0)

        browser_root
          .locator(".embed-mode-composer .d-editor-input")
          .filter(visible: true)
          .fill("Edited content")
        browser_root
          .locator(".embed-mode-composer .docked-composer__submit-btn")
          .filter(visible: true)
          .click

        expect(
          browser_root.locator(".embed-mode-composer__editing").filter(visible: true),
        ).to have_count(0)
        expect(
          browser_root.locator("#post_#{own_post.post_number}").filter(visible: true),
        ).to contain_text([browser_text_pattern("Edited content")], useInnerText: true)
      end

      context "with many replies" do
        before { 15.times { Fabricate(:post, topic: topic) } }

        it "shows floating timeline button when footer is not visible" do
          browser_page
            .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(topic_page).to have_post_number(2)

          expect(topic_page).to have_floating_timeline_button
          expect(topic_page).to have_no_floating_reply_button
        end

        it "opens the timeline when clicking the floating timeline button" do
          browser_page
            .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(topic_page).to have_post_number(2)

          topic_page.click_floating_timeline_button
          expect(
            browser_root.locator(".timeline-fullscreen.show").filter(visible: true),
          ).not_to have_count(0)
        end

        it "shows the topic progress bar at the bottom (not sticky)" do
          browser_page
            .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(topic_page).to have_post_number(2)

          expect(
            browser_root.locator("#topic-progress-wrapper").filter(visible: true),
          ).not_to have_count(0)
          expect(
            browser_root.locator(".topic-navigation.with-topic-progress").filter(visible: true),
          ).not_to have_count(0)
        end
      end

      it "does not show 'be the first to reply' message" do
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator(".embed-topic-footer__first-reply").filter(visible: true),
        ).to have_count(0)
      end

      it "still shows powered by discourse badge" do
        SiteSetting.enable_powered_by_discourse = true
        browser_page
          .goto("/t/#{topic.slug}/#{topic.id}?embed_mode=true")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }

        expect(
          browser_root.locator(".embed-topic-footer .powered-by-discourse").filter(visible: true),
        ).not_to have_count(0)
      end
    end
  end

  context "when not logged in" do
    fab!(:no_reply_topic, :topic)
    fab!(:no_reply_post) { Fabricate(:post, topic: no_reply_topic) }

    it "does not show the docked composer" do
      browser_page
        .goto("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(topic_page).to have_no_docked_composer
    end

    it "shows login label on the embed first-reply footer" do
      browser_page
        .goto("/t/#{no_reply_topic.slug}/#{no_reply_topic.id}?embed_mode=true")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator(
              "[id=#{I18n.t("js.topic.login_reply").to_s.to_json}], [name=#{I18n.t("js.topic.login_reply").to_s.to_json}]",
            ).or(browser_root.get_by_role("button", name: I18n.t("js.topic.login_reply"))),
          )
          .filter(visible: true),
      ).not_to have_count(0)
    end
  end
end
