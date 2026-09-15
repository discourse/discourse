# frozen_string_literal: true

describe "Hashtag decoration" do
  fab!(:attacker) { Fabricate(:trust_level_1, refresh_auto_groups: true) }
  fab!(:viewer, :user)
  fab!(:category)

  let(:composer) { PageObjects::Components::Composer.new }

  it "does not inject HTML from hostile hashtag attributes" do
    title = "Hashtag attribute injection"
    payload = <<~HTML.squish
      <a class="hashtag-cooked" data-type="category" data-id="#{category.id}" data-slug="#{category.slug}" data-style-type="square&quot;&gt;&lt;img data-hashtag-style-xss src=x&gt;">
      <span class="hashtag-icon-placeholder"></span><span>#{category.name}</span></a>
      <a class="hashtag-cooked" data-type="category" data-id="#{category.id}&quot;&gt;&lt;img data-hashtag-id-xss src=x&gt;" data-slug="#{category.slug}" data-style-type="square">
      <span class="hashtag-icon-placeholder"></span><span>#{category.name}</span></a>
    HTML

    sign_in(attacker)
    visit("/new-topic")
    composer.fill_title(title)
    composer.fill_content(payload)
    composer.create

    topic = Topic.find_by!(title: title)

    using_session(:viewer) do
      sign_in(viewer)
      visit("/t/#{topic.slug}/#{topic.id}")

      expect(page).to have_no_css(".cooked img[data-hashtag-style-xss]")
      expect(page).to have_no_css(".cooked img[data-hashtag-id-xss]")
    end
  end
end
