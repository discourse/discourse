# frozen_string_literal: true

describe "Using #hashtag autocompletion to search for and lookup channels", type: :system do
  fab!(:user) { Fabricate(:user) }
  fab!(:channel1) { Fabricate(:chat_channel, name: "Music Lounge", slug: "music") }
  fab!(:channel2) { Fabricate(:chat_channel, name: "Random", slug: "random") }
  fab!(:category) { Fabricate(:category, name: "Raspberry", slug: "raspberry-beret") }
  fab!(:tag) { Fabricate(:tag, name: "razed") }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:message1) { Fabricate(:chat_message, chat_channel: channel1) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    chat_system_bootstrap(user, [channel1, channel2])
    sign_in(user)
  end

  it "searches for channels, categories, and tags with # and prioritises channels in the results" do
    chat_page.visit_channel(channel1)
    chat_channel_page.composer.fill_in(with: "this is #ra")
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: 3,
    )
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 3)
    expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
      ["Random", "Raspberry", "razed (x0)"],
    )
  end

  it "searches for channels as well with # in a topic composer and deprioritises them" do
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer
    topic_page.type_in_composer("something #ra")
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: 3,
    )
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 3)
    expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
      ["Raspberry", "razed (x0)", "Random"],
    )
  end

  it "cooks the hashtags for channels, categories, and tags serverside when the chat message is saved to the database" do
    chat_page.visit_channel(channel1)
    chat_channel_page.type_in_composer(
      "this is #random and this is #raspberry-beret and this is #razed which is cool",
    )
    chat_channel_page.click_send_message

    message = nil
    try_until_success do
      message =
        Chat::Message.find_by(
          user: user,
          message: "this is #random and this is #raspberry-beret and this is #razed which is cool",
        )
      expect(message).not_to eq(nil)
    end
    expect(chat_channel_page.messages).to have_message(id: message.id)

    expect(page).to have_css(".hashtag-cooked[aria-label]", count: 3)

    cooked_hashtags = page.all(".hashtag-cooked", count: 3)

    expect(cooked_hashtags[0]["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: channel2.relative_url,
        "data-type": "channel",
        "data-slug": "random",
        "data-id": channel2.id,
        "aria-label": "Random",
      },
    ) do
      with_tag(
        "svg",
        with: {
          class:
            "fa d-icon d-icon-comment svg-icon hashtag-color--channel-#{channel2.id} svg-string",
        },
      ) { with_tag("use", with: { href: "#comment" }) }
    end

    expect(cooked_hashtags[1]["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category.url,
        "data-type": "category",
        "data-slug": "raspberry-beret",
        "data-id": category.id,
        "aria-label": "Raspberry",
      },
    ) do
      with_tag(
        "span",
        with: {
          class: "hashtag-category-badge hashtag-color--category-#{category.id}",
        },
      )
    end

    expect(cooked_hashtags[2]["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": "razed",
        "data-id": tag.id,
        "aria-label": "razed",
      },
    ) do
      with_tag(
        "svg",
        with: {
          class: "fa d-icon d-icon-tag svg-icon hashtag-color--tag-#{tag.id} svg-string",
        },
      ) { with_tag("use", with: { href: "#tag" }) }
    end
  end

  context "when a user cannot access the category for a cooked channel hashtag" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:manager_group) { Fabricate(:group, name: "Managers") }
    fab!(:private_category) do
      Fabricate(:private_category, name: "Management", slug: "management", group: manager_group)
    end
    fab!(:admin_group_user) { Fabricate(:group_user, user: admin, group: manager_group) }
    fab!(:management_channel) do
      Fabricate(:chat_channel, chatable: private_category, slug: "management")
    end
    fab!(:post_with_private_category) do
      Fabricate(
        :post,
        topic: topic,
        raw: "this is a secret #management::channel channel",
        user: admin,
      )
    end
    fab!(:message_with_private_channel) do
      Fabricate(
        :chat_message,
        chat_channel: channel1,
        user: admin,
        message: "this is a secret #management channel",
      )
    end

    before { management_channel.add(admin) }

    it "shows a default color and css class for the channel icon in a post" do
      topic_page.visit_topic(topic, post_number: post_with_private_category.post_number)
      expect(page).to have_css(".hashtag-cooked")
      expect(page).to have_css(".hashtag-cooked .hashtag-missing")
    end

    it "shows a default color and css class for the channel icon in a channel" do
      chat_page.visit_channel(channel1)
      expect(page).to have_css(".hashtag-cooked")
      expect(page).to have_css(".hashtag-cooked .hashtag-missing")
    end
  end
end
