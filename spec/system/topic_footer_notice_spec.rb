# frozen_string_literal: true

describe "Topic footer notice" do
  fab!(:post)
  fab!(:moderator)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:notice) { "Read the <em>posting rules</em> before replying." }

  it "lets staff publish and remove a plain-text notice from the topic footer" do
    SiteSetting.enable_topic_footer_notices = true
    sign_in(moderator)
    topic_page.visit_topic(post.topic)
    topic_page.click_admin_menu_button
    click_button I18n.t("js.topic.footer_staff_notice.add")

    within(".edit-topic-footer-notice") do
      fill_in I18n.t("js.topic.footer_staff_notice.message"), with: notice
      click_button I18n.t("js.save")
    end

    expect(page).to have_css(".topic-footer-notice", text: notice)
    expect(page).to have_css(
      ".topic-footer-notice + #topic-footer-buttons, .topic-footer-notice ~ #topic-footer-buttons",
    )

    topic_page.click_admin_menu_button
    click_button I18n.t("js.topic.footer_staff_notice.edit")
    within(".edit-topic-footer-notice") do
      fill_in I18n.t("js.topic.footer_staff_notice.message"), with: ""
      click_button I18n.t("js.save")
    end

    expect(page).to have_no_css(".topic-footer-notice")
  end
end
