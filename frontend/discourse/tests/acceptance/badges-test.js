import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import badgesFixtures from "discourse/tests/fixtures/badges-fixture";
import userBadgesFixtures from "discourse/tests/fixtures/user-badges";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Badges", function (needs) {
  needs.user();

  test("Visit Badge Pages", async function (assert) {
    await visit("/badges");

    assert.dom(document.body).hasClass("badges-page", "has body class");
    assert.dom(".badge-groups .badge-card").exists("has a list of badges");
    assert
      .dom(".badge-grouping h2#getting-started")
      .exists("badge grouping titles have slugified ids");

    await visit("/badges/9/autobiographer");

    assert.dom(".badge-card").exists("has the badge in the listing");
    assert.dom(".user-info").exists("has the list of users with that badge");
    assert.dom(".badge-card:nth-of-type(1) script").doesNotExist();
  });

  test("shows correct badge titles to choose from", async function (assert) {
    await visit("/badges/50/custombadge");
    await click(".badge-grant-info .btn-default");

    const availableBadgeTitles = selectKit(".badge-set-title .select-kit");
    await availableBadgeTitles.expand();

    assert.strictEqual(
      availableBadgeTitles.rowByIndex(1).name(),
      "CustomBadge"
    );
  });
});

acceptance("Badges - favorites", function (needs) {
  needs.user();
  needs.settings({ max_favorite_badges: 1 });

  let isFavorite;
  const firstButton = '[data-badge-slug="badge-8"] .favorite-btn';
  const secondButton = '[data-badge-slug="custombadge"] .favorite-btn';

  needs.hooks.beforeEach(() => {
    isFavorite = false;
  });

  needs.pretender((server, helper) => {
    server.get("/user-badges/eviltrout.json", () => {
      const payload = cloneJSON(userBadgesFixtures["/user-badges/:username"]);
      payload.badges.find((badge) => badge.id === 880).slug = "badge-8";
      payload.badges.find((badge) => badge.id === 50).slug = "custombadge";
      payload.user_badges.forEach((userBadge) => {
        userBadge.can_favorite = true;
        userBadge.is_favorite = userBadge.badge_id === 880 && isFavorite;
      });
      return helper.response(payload);
    });
    server.put("/user_badges/668/toggle_favorite", () => {
      isFavorite = !isFavorite;
      return helper.response({ user_badge: { is_favorite: isFavorite } });
    });
  });

  test("favoriting a badge updates the count and enforces the limit", async function (assert) {
    await visit("/u/eviltrout/badges");

    assert
      .dom(".favorite-count")
      .hasText(
        i18n("badges.favorite_count", { count: 0, max: 1 }),
        "no badges are initially favorited"
      );
    assert.dom(secondButton).isEnabled("another badge can be favorited");

    await click(firstButton);

    assert.true(isFavorite, "the server receives the favorite request");
    assert.dom(`${firstButton} .d-icon-star`).exists("the badge is favorited");
    assert
      .dom(".favorite-count")
      .hasText(
        i18n("badges.favorite_count", { count: 1, max: 1 }),
        "the favorite count updates without reloading"
      );
    assert.dom(secondButton).isDisabled("the favorite limit is enforced");

    await click(firstButton);

    assert.false(isFavorite, "the server receives the unfavorite request");
    assert
      .dom(`${firstButton} .d-icon-far-star`)
      .exists("the favorite is removed");
    assert
      .dom(".favorite-count")
      .hasText(
        i18n("badges.favorite_count", { count: 0, max: 1 }),
        "the count stays reactive across consecutive toggles"
      );
    assert.dom(secondButton).isEnabled("the favorite slot is available again");
  });
});

acceptance("Badges - granting post link", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/user_badges.json", () => {
      const payload = cloneJSON(badgesFixtures["/user_badges.json"]);
      payload.topics = [
        {
          id: 280,
          title: "A granting topic",
          fancy_title: "A granting topic",
          slug: "a-granting-topic",
          posts_count: 3,
        },
      ];
      payload.user_badges = [
        {
          ...payload.user_badges[0],
          post_number: 2,
          topic_id: 280,
        },
        // Topic the viewer can't see, so the sideload omits it: reading an
        // absent sideload used to throw.
        {
          ...payload.user_badges[1],
          post_number: 5,
          topic_id: 999,
        },
      ];
      return helper.response(payload);
    });
  });

  test("links to the post that granted the badge", async function (assert) {
    await visit("/badges/9/autobiographer");

    assert
      .dom(".badges-granted a.post-link")
      .hasAttribute(
        "href",
        "/t/a-granting-topic/280/2",
        "links to the granting post"
      )
      .hasText("A granting topic", "shows the topic title");
  });
});
