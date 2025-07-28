# frozen_string_literal: true

describe "Using #hashtag autocompletion to search for and lookup categories and tags",
         type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category) do
    Fabricate(:category, name: "Cool Category", slug: "cool-cat", topic_count: 3234)
  end
  fab!(:category2) do
    Fabricate(:category, name: "Other Category", slug: "other-cat", topic_count: 23)
  end
  fab!(:tag) { Fabricate(:tag, name: "cooltag", staff_topic_count: 324, public_topic_count: 324) }
  fab!(:tag2) { Fabricate(:tag, name: "othertag", staff_topic_count: 66, public_topic_count: 66) }
  fab!(:topic) { Fabricate(:topic, category: category, tags: [tag]) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:uncategorized_category) { Category.find(SiteSetting.uncategorized_category_id) }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }
  before { SiteSetting.floatkit_autocomplete_composer = false }

  def visit_topic_and_initiate_autocomplete(initiation_text: "something #co", expected_count: 2)
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer
    topic_page.type_in_composer(initiation_text)
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: expected_count,
    )
  end

  it "searches for categories and tags with # and prioritises categories in the results" do
    visit_topic_and_initiate_autocomplete
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
    expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
      ["Cool Category", "cooltag (x325)"],
    )
  end

  it "begins showing results as soon as # is pressed based on categories and tags topic_count" do
    visit_topic_and_initiate_autocomplete(initiation_text: "#", expected_count: 5)
    hashtag_results = page.all(".hashtag-autocomplete__link")
    expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
      [
        "Cool Category",
        "Other Category",
        uncategorized_category.name,
        "cooltag (x325)",
        "othertag (x66)",
      ],
    )
  end

  it "cooks the selected hashtag clientside in the composer preview with the correct url and icon" do
    visit_topic_and_initiate_autocomplete
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
    hashtag_results[0].click
    expect(page).to have_css(".hashtag-cooked")
    cooked_hashtag = page.find(".hashtag-cooked")

    expect(cooked_hashtag["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category.url,
        "data-type": "category",
        "data-slug": category.slug,
        "data-id": category.id,
      },
    ) do
      with_tag(
        "span",
        with: {
          class: "hashtag-category-square hashtag-color--category-#{category.id}",
        },
      )
    end

    visit_topic_and_initiate_autocomplete
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
    hashtag_results[1].click
    expect(page).to have_css(".hashtag-cooked")
    cooked_hashtag = page.find(".hashtag-cooked")
    expect(cooked_hashtag["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": tag.name,
        "data-id": tag.id,
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

  it "cooks the hashtags for tag and category correctly serverside when the post is saved to the database" do
    topic_page.visit_topic_and_open_composer(topic)

    expect(topic_page).to have_expanded_composer

    topic_page.send_reply("this is a #cool-cat category and a #cooltag tag")

    expect(topic_page).to have_post_number(2)

    cooked_hashtags = page.all(".hashtag-cooked", count: 2)

    expect(cooked_hashtags[0]["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category.url,
        "data-type": "category",
        "data-slug": category.slug,
        "data-id": category.id,
        "aria-label": category.name,
      },
    ) do
      with_tag(
        "span",
        with: {
          class: "hashtag-category-square hashtag-color--category-#{category.id}",
        },
      )
    end

    expect(cooked_hashtags[1]["outerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": tag.name,
        "data-id": tag.id,
        "aria-label": tag.name,
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

  it "decorates post small actions with hashtags in the custom message" do
    post =
      Fabricate(:small_action, raw: "this is a #cool-cat category and a #cooltag tag", topic: topic)
    topic_page.visit_topic(topic)
    expect(topic_page).to have_post_number(post.post_number)
    expect(find(".small-action-custom-message")["innerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": tag.name,
        "data-id": tag.id,
        "aria-label": tag.name,
      },
    ) do
      with_tag(
        "svg",
        with: {
          class: "fa d-icon d-icon-tag svg-icon hashtag-color--tag-#{tag.id} svg-string",
        },
      ) { with_tag("use", with: { href: "#tag" }) }
    end
    expect(find(".small-action-custom-message")["innerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category.url,
        "data-type": "category",
        "data-slug": category.slug,
        "data-id": category.id,
        "aria-label": category.name,
      },
    ) do
      with_tag(
        "span",
        with: {
          class: "hashtag-category-square hashtag-color--category-#{category.id}",
        },
      )
    end
  end

  it "decorates the user activity stream hashtags" do
    post =
      Fabricate(
        :post,
        raw: "this is a #cool-cat category and a #cooltag tag",
        topic: topic,
        user: current_user,
      )
    UserActionManager.enable
    UserActionManager.post_created(post)

    visit("/u/#{current_user.username}/activity")
    expect(find(".user-stream-item [data-post-id=\"#{post.id}\"]")["innerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: category.url,
        "data-type": "category",
        "data-slug": category.slug,
        "data-id": category.id,
        "aria-label": category.name,
      },
    ) do
      with_tag(
        "span",
        with: {
          class: "hashtag-category-square hashtag-color--category-#{category.id}",
        },
      )
    end
    expect(find(".user-stream-item [data-post-id=\"#{post.id}\"]")["innerHTML"]).to have_tag(
      "a",
      with: {
        class: "hashtag-cooked",
        href: tag.url,
        "data-type": "tag",
        "data-slug": tag.name,
        "data-id": tag.id,
        "aria-label": tag.name,
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

  context "when a user cannot access the category for a hashtag cooked in another post" do
    fab!(:admin)
    fab!(:manager_group) { Fabricate(:group, name: "Managers") }
    fab!(:private_category) do
      Fabricate(:private_category, name: "Management", slug: "management", group: manager_group)
    end
    fab!(:admin_group_user) { Fabricate(:group_user, user: admin, group: manager_group) }
    fab!(:post_with_private_category) do
      Fabricate(:post, topic: topic, raw: "this is a secret #management category", user: admin)
    end

    it "shows a default color and css class for the category icon square" do
      topic_page.visit_topic(topic, post_number: post_with_private_category.post_number)
      expect(page).to have_css(".hashtag-cooked .hashtag-category-square")
      generated_css = find("#hashtag-css-generator", visible: false).text(:all)
      expect(generated_css).to include(".hashtag-category-square")
      expect(generated_css).not_to include(".hashtag-color--category--#{private_category.id}")
    end
  end

  context "with floatkit autocomplete enabled" do
    before { SiteSetting.floatkit_autocomplete_composer = true }

    it "searches for categories and tags with # and prioritises categories in the results" do
      visit_topic_and_initiate_autocomplete
      hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
      expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
        ["Cool Category", "cooltag (x325)"],
      )
    end

    it "begins showing results as soon as # is pressed based on categories and tags topic_count" do
      visit_topic_and_initiate_autocomplete(initiation_text: "#", expected_count: 5)
      hashtag_results = page.all(".hashtag-autocomplete__link")
      expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
        [
          "Cool Category",
          "Other Category",
          uncategorized_category.name,
          "cooltag (x325)",
          "othertag (x66)",
        ],
      )
    end

    it "cooks the selected hashtag clientside in the composer preview with the correct url and icon" do
      visit_topic_and_initiate_autocomplete
      hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
      hashtag_results[0].click
      expect(page).to have_css(".hashtag-cooked")
      cooked_hashtag = page.find(".hashtag-cooked")

      expect(cooked_hashtag["outerHTML"]).to have_tag(
        "a",
        with: {
          class: "hashtag-cooked",
          href: category.url,
          "data-type": "category",
          "data-slug": category.slug,
          "data-id": category.id,
        },
      ) do
        with_tag(
          "span",
          with: {
            class: "hashtag-category-square hashtag-color--category-#{category.id}",
          },
        )
      end

      visit_topic_and_initiate_autocomplete
      hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
      hashtag_results[1].click
      expect(page).to have_css(".hashtag-cooked")
      cooked_hashtag = page.find(".hashtag-cooked")
      expect(cooked_hashtag["outerHTML"]).to have_tag(
        "a",
        with: {
          class: "hashtag-cooked",
          href: tag.url,
          "data-type": "tag",
          "data-slug": tag.name,
          "data-id": tag.id,
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

    it "cooks the hashtags for tag and category correctly serverside when the post is saved to the database" do
      topic_page.visit_topic_and_open_composer(topic)

      expect(topic_page).to have_expanded_composer

      topic_page.send_reply("this is a #cool-cat category and a #cooltag tag")

      expect(topic_page).to have_post_number(2)

      cooked_hashtags = page.all(".hashtag-cooked", count: 2)

      expect(cooked_hashtags[0]["outerHTML"]).to have_tag(
        "a",
        with: {
          class: "hashtag-cooked",
          href: category.url,
          "data-type": "category",
          "data-slug": category.slug,
          "data-id": category.id,
          "aria-label": category.name,
        },
      ) do
        with_tag(
          "span",
          with: {
            class: "hashtag-category-square hashtag-color--category-#{category.id}",
          },
        )
      end

      expect(cooked_hashtags[1]["outerHTML"]).to have_tag(
        "a",
        with: {
          class: "hashtag-cooked",
          href: tag.url,
          "data-type": "tag",
          "data-slug": tag.name,
          "data-id": tag.id,
          "aria-label": tag.name,
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
  end
end
