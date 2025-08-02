# frozen_string_literal: true

describe "Tags intersection", type: :system do
  let(:discovery) { PageObjects::Pages::Discovery.new }

  fab!(:category) { Fabricate(:category, name: "fruits") }
  fab!(:some_topic) { Fabricate(:topic, category: category) }

  fab!(:tag) { Fabricate(:tag, name: "sour") }
  fab!(:tag2) { Fabricate(:tag, name: "tangy") }
  fab!(:some_topic) { Fabricate(:topic, tags: [tag, tag2]) }

  fab!(:the_topic) { Fabricate(:topic, category: category, tags: [tag, tag2]) }

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
end
