# frozen_string_literal: true

describe "Topic page" do
  fab!(:topic)
  fab!(:admin)

  before { Fabricate(:post, topic: topic, cooked: <<~HTML) }
    <h2 dir="ltr" id="toc-h2-testing" data-d-toc="toc-h2-testing" class="d-toc-post-heading">
      <a name="toc-h2-testing" class="anchor" href="#toc-h2-testing" aria-label="Heading link">x</a>
      Testing
    </h2>
    <p id="test-last-cooked-paragraph">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat risus. Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan. Vestibulum feugiat mi vitae turpis tempor dignissim.</p>
    HTML

  it "allows TOC anchor navigation" do
    visit("/t/#{topic.slug}/#{topic.id}")

    find("#toc-h2-testing .anchor", visible: :all).click

    expect(current_url).to match("/t/#{topic.slug}/#{topic.id}#toc-h2-testing")
  end

  context "with a subfolder setup" do
    before { set_subfolder "/forum" }

    it "allows TOC anchor navigation" do
      visit("/forum/t/#{topic.slug}/#{topic.id}")

      find("#toc-h2-testing .anchor", visible: :all).click

      expect(current_url).to match("/forum/t/#{topic.slug}/#{topic.id}#toc-h2-testing")
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

      PostDestroyer.new(Discourse.system_user, post2, context: "Automated testing").destroy
      PostDestroyer.new(Discourse.system_user, post3, context: "Automated testing").destroy

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

  context "with rich content" do
    fab!(:user_1, :user)
    fab!(:user_2, :user)
    fab!(:topic2, :topic)

    before do
      Fabricate(:post, topic: topic2, user: user_1, cooked: <<~HTML)
        <h2>Key Takeaways</h2>
        <p>After reviewing this topic, here are the main points:</p>
        <ul>
          <li><strong>Performance matters</strong>: always benchmark first</li>
          <li><em>Readability</em>: code is read more often than written</li>
          <li>Testing: write tests before writing code</li>
        </ul>
        <p>Use <code>inline code</code> to clarify technical details.</p>
        <aside class="onebox githubpullrequest" data-onebox-src="https://github.com/discourse/discourse/pull/38698">
          <header class="source">
            <a href="https://github.com/discourse/discourse/pull/38698" target="_blank" rel="noopener">github.com</a>
          </header>
          <article class="onebox-body">
            <div class="github-row">
              <div class="github-icon-container" title="Pull Request">
                <svg width="60" height="60" class="github-icon" viewBox="0 0 14 16" aria-hidden="true"><path fill-rule="evenodd" d="M10.86 7c-.45-1.72-2-3-3.86-3-1.86 0-3.41 1.28-3.86 3H0v2h3.14c.45 1.72 2 3 3.86 3 1.86 0 3.41-1.28 3.86-3H14V7h-3.14zM7 10.2c-1.22 0-2.2-.98-2.2-2.2 0-1.22.98-2.2 2.2-2.2 1.22 0 2.2.98 2.2 2.2 0 1.22-.98 2.2-2.2 2.2z"></path></svg>
              </div>
              <div class="github-info-container">
                <h4><a href="https://github.com/discourse/discourse/pull/38698" target="_blank" rel="noopener">DEV: Add example pull request for onebox testing</a></h4>
                <div class="github-info">
                  <div class="date">opened Jan 15, 2026</div>
                  <div class="user">discourse</div>
                </div>
              </div>
            </div>
          </article>
          <div class="onebox-metadata"></div>
          <div style="clear: both"></div>
        </aside>
        <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean eget ex id diam pulvinar tempor ut id nisi. Nam non nisl tellus. Cras sodales eu diam scelerisque molestie. Curabitur neque ante, feugiat sit amet nisl vitae, accumsan convallis lacus. Nam nec velit dolor. Morbi vulputate erat lorem, et semper ex sodales id. In non iaculis dui. Morbi dolor est, pulvinar vel gravida ut, feugiat sed mi. Praesent tincidunt dictum turpis.</p>
        HTML

      Fabricate(:post_with_rich_content, topic: topic2, user: admin)
    end

    it "renders all content types and scrolls to the last post" do
      visit "/t/#{topic2.slug}/#{topic2.id}"

      expect(page).to have_css("h2", text: "Key Takeaways")
      expect(page).to have_css("blockquote")
      expect(page).to have_css(".emoji")

      screenshot_marker(label: "topic-rich-content")

      send_keys(:end)
      expect(find("#post_#{topic2.reload.highest_post_number}")).to be_visible
    end
  end

  context "when triple clicking to select a paragraph" do
    it "select the last paragraph" do
      visit "/t/#{topic.slug}/#{topic.id}/1"

      paragraph = find("#test-last-cooked-paragraph")

      page.driver.with_playwright_page do |pw_page|
        paragraph.hover

        rect = paragraph.native.bounding_box
        x = rect["x"] + rect["width"] / 2
        y = rect["y"] + rect["height"] / 2

        pw_page.mouse.click(x, y, clickCount: 3)
      end

      # get the selected text in the browser
      select_content = page.evaluate_script("window.getSelection().toString()")

      # the browser is returning control characters among the whiter space in the end of the text
      # this regex will work as a .rstrip on steroids and remove them
      select_content.gsub!(/[\s\p{Cf}]+$/, "")

      # compare the selected text with the last paragraph
      expect(select_content).to eq(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc convallis volutpat risus. Nulla ac faucibus quam, quis cursus lorem. Sed rutrum eget nunc sed accumsan. Vestibulum feugiat mi vitae turpis tempor dignissim.",
      )
    end
  end
end
