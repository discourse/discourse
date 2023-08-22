# frozen_string_literal: true

describe "Topic page", type: :system do
  fab!(:topic) { Fabricate(:topic) }

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
end
