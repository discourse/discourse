# frozen_string_literal: true

RSpec.describe "Category hashtag decoration" do
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:viewer, :user)
  fab!(:category)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  it "does not turn hostile category hashtag attributes into viewer-visible HTML" do
    sign_in(author)
    topic_page.open_new_topic
    composer.fill_title("Hostile category hashtag attributes")
    composer.fill_content(<<~HTML)
      <a class="hashtag-cooked" data-type="category" data-id="#{category.id}" data-style-type='"><img class="style-type-injected-image">'><span class="hashtag-icon-placeholder"></span>#{category.name}</a>
      <a class="hashtag-cooked" data-type="category" data-id='#{category.id}"><img class="id-injected-image">' data-style-type="square"><span class="hashtag-icon-placeholder"></span>#{category.name}</a>
    HTML
    composer.create

    topic = Topic.find_by!(title: "Hostile category hashtag attributes")
    sign_in(viewer)
    topic_page.visit_topic(topic)

    expect(page).to have_css("#post_1 .hashtag-cooked", count: 2)
    expect(page).to have_no_css("#post_1 .style-type-injected-image")
    expect(page).to have_no_css("#post_1 .id-injected-image")
  end
end
