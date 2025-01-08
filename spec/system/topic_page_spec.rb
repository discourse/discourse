# frozen_string_literal: true

describe "Topic page", type: :system do
  fab!(:topic)
  fab!(:admin)

  before { Fabricate(:post, topic: topic, cooked: <<~HTML) }
    <h2 dir="ltr" id="toc-h2-testing" data-d-toc="toc-h2-testing" class="d-toc-post-heading">
      <a name="toc-h2-testing" class="anchor" href="#toc-h2-testing">x</a>
      Testing
    </h2>
    <p id="test-last-cooked-paragraph">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tempor.</p>
    HTML

  it "allows TOC anchor navigation" do
    visit("/t/#{topic.slug}/#{topic.id}")

    find("#toc-h2-testing .anchor", visible: :all).click

    try_until_success do
      expect(current_url).to match("/t/#{topic.slug}/#{topic.id}#toc-h2-testing")
    end
  end

  context "with a subfolder setup" do
    before { set_subfolder "/forum" }

    it "allows TOC anchor navigation" do
      visit("/forum/t/#{topic.slug}/#{topic.id}")

      find("#toc-h2-testing .anchor", visible: :all).click

      try_until_success do
        expect(current_url).to match("/forum/t/#{topic.slug}/#{topic.id}#toc-h2-testing")
      end
    end
  end

  context "with a post containing a code block" do
    before { Fabricate(:post, topic: topic, raw: <<~RAW) }
      this a code block
      ```
      echo "hello world"
      ```
      RAW

    it "includes the copy button" do
      visit("/t/#{topic.slug}/#{topic.id}")

      expect(".codeblock-button-wrapper").to be_present
    end
  end

  context "with a gap" do
    before do
      post2 = Fabricate(:post, topic: topic, cooked: "post2")
      post3 = Fabricate(:post, topic: topic, cooked: "post3")
      post4 = Fabricate(:post, topic: topic, cooked: "post4")

      PostDestroyer.new(Discourse.system_user, post2).destroy
      PostDestroyer.new(Discourse.system_user, post3).destroy

      sign_in admin
    end

    it "displays the gap to admins, and allows them to expand it" do
      visit "/t/#{topic.slug}/#{topic.id}"

      expect(page).to have_css(".topic-post", count: 2)
      find(".post-stream .gap").click()
      expect(page).to have_css(".topic-post", count: 4)
    end
  end

  it "supports shift+a kbd shortcut to toggle admin menu" do
    sign_in admin

    visit("/t/#{topic.slug}/#{topic.id}")

    expect(".toggle-admin-menu").to be_present

    send_keys([:shift, "a"])

    expect(page).to have_css(".topic-admin-menu-content")

    send_keys([:shift, "a"])

    expect(page).to have_no_css(".topic-admin-menu-content")
  end

  context "with End keyboard shortcut" do
    fab!(:posts) { Fabricate.times(25, :post, topic: topic) }

    it "loads last post" do
      visit "/t/#{topic.slug}/#{topic.id}/1"

      send_keys(:end)

      expect(find("#post_#{topic.highest_post_number}")).to be_visible
    end
  end

  context "when triple clicking to select a paragraph" do
    it "select the last paragraph" do
      visit "/t/#{topic.slug}/#{topic.id}/1"

      # ensure #test-last-cooked-paragraph is the last paragraph of #post_1.cooked just in case the cooked content of the
      # post is changed in the future. this ensures we testing what we need.
      last_cooked_child_id = page.find("#post_1 .cooked >:last-child")[:id]
      expect(last_cooked_child_id).to eq("test-last-cooked-paragraph")

      # select the last paragraph by triple clicking
      element = page.driver.browser.find_element(id: "test-last-cooked-paragraph")
      page.driver.browser.action.move_to(element).click.click.click.perform

      # get the selected text in the browser
      select_content = page.evaluate_script("window.getSelection().toString()")

      # the browser is returning control characters among the whiter space in the end of the text
      # this regex will work as a .rstrip on steroids and remove them
      select_content.gsub!(/[\s\p{Cf}]+$/, "")

      # compare the selected text with the last paragraph
      expect(select_content).to eq(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tempor.",
      )
    end
  end
end
