# frozen_string_literal: true

describe "Topic page", type: :system do
  fab!(:topic)
  fab!(:admin)

  before { Fabricate(:post, topic: topic, cooked: <<~HTML) }
    <h2 dir="ltr" id="toc-h2-testing" data-d-toc="toc-h2-testing" class="d-toc-post-heading">
      <a name="toc-h2-testing" class="anchor" href="#toc-h2-testing">x</a>
      Testing
    </h2>
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
end
