# frozen_string_literal: true

describe "Tags intersection", type: :system do
  let(:discovery) { PageObjects::Pages::Discovery.new }

  fab!(:category) { Fabricate(:category, name: "fruits") }

  fab!(:tag) { Fabricate(:tag, name: "sour") }
  fab!(:tag2) { Fabricate(:tag, name: "tangy") }
  fab!(:tag3) { Fabricate(:tag, name: "sweet") }

  fab!(:tagged_topic) { Fabricate(:topic, tags: [tag, tag2, tag3]) }
  fab!(:the_topic) { Fabricate(:topic, category:, tags: [tag, tag2, tag3]) }

  it "filters by category" do
    visit("/tags/intersection/sour/tangy?category=fruits")

    expect(page).to have_current_path("/tags/intersection/sour/tangy?category=fruits")
    expect(discovery.topic_list).to have_topic(the_topic)
    expect(discovery.topic_list).to have_topics(count: 1)

    visit("/")

    # Confirm that frontend transitions work as well,
    # even though UI doesn't support that
    page.execute_script <<~JS
      require("discourse/lib/url").default.routeTo("/tags/intersection/sour/tangy?category=fruits")
    JS

    expect(page).to have_current_path("/tags/intersection/sour/tangy?category=fruits")
    expect(discovery.topic_list).to have_topic(the_topic)
    expect(discovery.topic_list).to have_topics(count: 1)
  end

  it "shortens and redirects URLs" do
    visit("/tags/intersection/sour/tangy/sour")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")

    visit("/tags/intersection/sour/tangy/sour/sour")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")

    visit("/tags/intersection/sour/sour")
    expect(page).to have_current_path("/tag/#{tag.slug}/#{tag.id}")
  end

  it "removes duplicates from the additional tags list" do
    visit("/tags/intersection/sour/tangy/tangy")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")

    visit("/tags/intersection/sour/tangy/tangy/tangy")
    expect(page).to have_current_path("/tags/intersection/sour/tangy")
  end

  it "navigates correctly when adding and removing tags from the intersection chooser" do
    visit("/tags/intersection/sour/tangy")

    chooser = PageObjects::Components::SelectKit.new(".tags-intersection-chooser")
    chooser.expand
    chooser.select_row_by_name("sweet")

    expect(page).to have_current_path("/tags/intersection/sour/tangy/sweet")
    expect(discovery.topic_list).to have_topics(count: 2)

    chooser.unselect_by_name("tangy")

    expect(page).to have_current_path("/tags/intersection/sour/sweet")
  end
end
