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
    assert
      .dom(".show-badge-details .badge-granted")
      .includesText("awarded", "shows the site-wide grant count");
    assert.dom(".user-info").exists("has the list of users with that badge");
    assert.dom(".badge-card:nth-of-type(1) script").doesNotExist();
  });

  test("marks a held badge as granted and offers it as a title", async function (assert) {
    await visit("/badges/50/custombadge");

    assert
      .dom(".show-badge-details .check-display")
      .exists("the badge is marked as granted");

    await click(".badge-grant-info .btn-default");

    const availableBadgeTitles = selectKit(".badge-set-title .select-kit");
    await availableBadgeTitles.expand();

    assert.strictEqual(
      availableBadgeTitles.rowByIndex(1).name(),
      "CustomBadge"
    );
  });

  test("closes the title picker when leaving the badge page", async function (assert) {
    await visit("/badges/50/custombadge");
    await click(".badge-grant-info .btn-default");

    assert.dom(".badge-set-title").exists();

    await visit("/badges");
    await visit("/badges/50/custombadge");

    assert.dom(".badge-set-title").doesNotExist();
    assert.dom(".badge-grant-info .btn-default").exists();
  });
});

acceptance("Badges - filtered by username", function (needs) {
  needs.user();

  const grant = (id, badgeId, userId) => ({
    id,
    granted_at: "2014-07-03T06:36:46.939-04:00",
    badge_id: badgeId,
    user_id: userId,
    granted_by_id: -1,
  });

  let customBadgeGrants;

  needs.hooks.beforeEach(() => {
    customBadgeGrants = [grant(9001, 50, 19), grant(9002, 50, 11234)];
  });

  needs.pretender((server, helper) => {
    server.get(
      "/user_badges.json",
      ({ queryParams: { badge_id, username } }) => {
        const { user_badges, ...payload } = cloneJSON(
          badgesFixtures["/user_badges.json"]
        );
        const user = payload.users.find((u) => u.username === username);
        const userBadges = [...user_badges, ...customBadgeGrants].filter(
          (ub) => ub.badge_id === Number(badge_id) && ub.user_id === user.id
        );
        payload.user_badge_info = {
          grant_count: userBadges.length,
          username,
          user_badges: userBadges,
        };
        return helper.response(payload);
      }
    );
  });

  test("shows another user's data, not the current user's", async function (assert) {
    await visit("/badges/9/autobiographer?username=allard");

    assert
      .dom(".show-badge-details .check-display")
      .exists("the filtered user holds the badge, even if the viewer doesn't");
    assert
      .dom("#show-others-with-badge-link")
      .exists("links to everyone else with the badge");

    await visit("/badges/50/custombadge?username=allard");

    assert
      .dom(".badge-grant-info .btn-default")
      .doesNotExist("the viewer's title picker is hidden");
  });

  test("doesn't mark the badge as granted when the filtered user lacks it", async function (assert) {
    await visit("/badges/50/custombadge?username=daydreamer");

    assert
      .dom(".show-badge-details .check-display")
      .doesNotExist("the viewer holding the badge doesn't count");
    assert.dom(".show-badge-details .badge-granted").doesNotExist();
    assert.dom(".badge-grant-info .btn-default").doesNotExist();
  });

  test("keeps the title picker when filtered to the current user", async function (assert) {
    await visit("/badges/50/custombadge?username=eviltrout");

    assert.dom(".badge-grant-info .btn-default").exists();
  });

  test("hides the others link when the filtered user holds every grant", async function (assert) {
    customBadgeGrants = Array.from({ length: 10 }, (_, i) =>
      grant(9100 + i, 50, 11234)
    );

    await visit("/badges/50/custombadge?username=allard");

    assert.dom(".badges-granted .badge-info").exists({ count: 10 });
    assert.dom("#show-others-with-badge-link").doesNotExist();
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
