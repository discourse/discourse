# frozen_string_literal: true

describe "Using #hashtag autocompletion to search for and lookup categories and tags" do
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

  def visit_topic_and_initiate_autocomplete(initiation_text: "something #co", expected_count: 2)
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer
    topic_page.type_in_composer(initiation_text)
    expect(
      browser_root.locator(
        ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      ).filter(visible: true),
    ).to have_count(expected_count)
  end

  it "searches for categories and tags with # and prioritises categories in the results" do
    visit_topic_and_initiate_autocomplete
    hashtag_results =
      browser_root
        .locator(".hashtag-autocomplete__link")
        .filter(visible: true)
        .tap { |elements| expect(elements).to have_count(2) }
        .all
    expect(
      hashtag_results.map { |element| element.inner_text.strip }.map { |r| r.gsub("\n", " ") },
    ).to eq(["Cool Category", "cooltag (x325)"])
  end

  it "begins showing results as soon as # is pressed based on categories and tags topic_count" do
    visit_topic_and_initiate_autocomplete(initiation_text: "#", expected_count: 5)
    hashtag_results =
      browser_root
        .locator(".hashtag-autocomplete__link")
        .filter(visible: true)
        .tap { |elements| elements.first.wait_for(state: "visible") }
        .all
    expect(
      hashtag_results.map { |element| element.inner_text.strip }.map { |r| r.gsub("\n", " ") },
    ).to eq(
      [
        "Cool Category",
        "Other Category",
        uncategorized_category.name,
        "cooltag (x325)",
        "othertag (x66)",
      ],
    )
  end

  it "cooks the selected category hashtag clientside in the composer preview with the correct url and icon" do
    visit_topic_and_initiate_autocomplete
    hashtag_results =
      browser_root
        .locator(".hashtag-autocomplete__link")
        .filter(visible: true)
        .tap { |elements| expect(elements).to have_count(2) }
        .all
    hashtag_results[0].click
    expect(browser_root.locator(".hashtag-cooked").filter(visible: true)).not_to have_count(0)
    cooked_hashtag = browser_root.locator(".hashtag-cooked").filter(visible: true)

    expect(
      cooked_hashtag.evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "outerHTML",
      ),
    ).to have_tag(
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
  end

  it "cooks the selected tag hashtag clientside in the composer preview with the correct url and icon" do
    visit_topic_and_initiate_autocomplete
    hashtag_results =
      browser_root
        .locator(".hashtag-autocomplete__link")
        .filter(visible: true)
        .tap { |elements| expect(elements).to have_count(2) }
        .all
    hashtag_results[1].click
    expect(browser_root.locator(".hashtag-cooked").filter(visible: true)).not_to have_count(0)
    cooked_hashtag = browser_root.locator(".hashtag-cooked").filter(visible: true)

    expect(
      cooked_hashtag.evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "outerHTML",
      ),
    ).to have_tag(
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

    cooked_hashtags =
      browser_root
        .locator(".hashtag-cooked")
        .filter(visible: true)
        .tap { |elements| expect(elements).to have_count(2) }
        .all

    expect(
      cooked_hashtags[0].evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "outerHTML",
      ),
    ).to have_tag(
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

    expect(
      cooked_hashtags[1].evaluate(
        "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
        arg: "outerHTML",
      ),
    ).to have_tag(
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
    expect(
      browser_root
        .locator(".small-action-custom-message")
        .filter(visible: true)
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "innerHTML",
        ),
    ).to have_tag(
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
    expect(
      browser_root
        .locator(".small-action-custom-message")
        .filter(visible: true)
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "innerHTML",
        ),
    ).to have_tag(
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

    browser_page
      .goto("/u/#{current_user.username}/activity")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root
        .locator(".user-stream-item [data-post-id=\"#{post.id}\"]")
        .filter(visible: true)
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "innerHTML",
        ),
    ).to have_tag(
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
    expect(
      browser_root
        .locator(".user-stream-item [data-post-id=\"#{post.id}\"]")
        .filter(visible: true)
        .evaluate(
          "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
          arg: "innerHTML",
        ),
    ).to have_tag(
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

  it "does not show hashtag autocomplete when typing a URL with anchor" do
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer

    # normal autocomplete works
    topic_page.type_in_composer("#co")
    expect(browser_root.locator(".hashtag-autocomplete").filter(visible: true)).not_to have_count(0)

    # autocomplete does not trigger within a URL
    topic_page.clear_composer
    topic_page.type_in_composer("discourse.org/#co")
    expect(browser_root.locator(".hashtag-autocomplete").filter(visible: true)).to have_count(
      0,
      timeout: 2 * 1000,
    )
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
      expect(
        browser_root.locator(".hashtag-cooked .hashtag-category-square").filter(visible: true),
      ).not_to have_count(0)
      generated_css = browser_root.locator("#hashtag-css-generator").text_content
      expect(generated_css).to include(".hashtag-category-square")
      expect(generated_css).not_to include(".hashtag-color--category--#{private_category.id}")
    end
  end
end
