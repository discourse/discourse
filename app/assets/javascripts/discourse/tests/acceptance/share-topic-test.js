import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import CategoryFixtures from "discourse/tests/fixtures/category-fixtures";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";

acceptance("Share and Invite modal", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get(`/c/2481/visible_groups.json`, () =>
      helper.response(200, {
        groups: ["group_name_1", "group_name_2"],
      })
    );

    server.get(`/c/2/visible_groups.json`, () =>
      helper.response(200, {
        groups: [],
      })
    );
  });

  test("Topic footer button", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#topic-footer-button-share-and-invite")
      .exists("the button exists");

    await click("#topic-footer-button-share-and-invite");

    assert.dom(".share-topic-modal").exists("shows the modal");

    assert
      .dom("#modal-alert.alert-warning")
      .doesNotExist("it does not show the alert with restricted groups");

    assert.ok(
      query("input.invite-link").value.includes(
        "/t/internationalization-localization/280?u=eviltrout"
      ),
      "it shows the topic sharing url"
    );

    assert
      .dom(".link-share-actions .invite")
      .exists("it shows the invite button");

    await click(".link-share-actions .invite");

    assert.dom(".create-invite-modal").exists();
  });

  test("Post date link", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54077");
    assert.ok(
      query("#post_2 .post-info.post-date a").href.endsWith(
        "/t/short-topic-with-two-posts/54077/2?u=eviltrout"
      )
    );

    await click("#post_2 a.post-date");
    assert.dom(".share-topic-modal").exists("shows the share modal");
    assert.strictEqual(
      currentURL(),
      "/t/short-topic-with-two-posts/54077",
      "it does not route to post #2"
    );
  });

  test("Share topic in a restricted category", async function (assert) {
    await visit("/t/topic-in-restricted-group/2481");

    assert
      .dom("#topic-footer-button-share-and-invite")
      .exists("the button exists");

    await click("#topic-footer-button-share-and-invite");

    assert.dom(".share-topic-modal").exists("shows the modal");
    assert
      .dom("#modal-alert.alert-warning")
      .exists("it shows restricted warning");
    assert.dom("#modal-alert.alert-warning").hasText(
      I18n.t("topic.share.restricted_groups", {
        count: 2,
        groupNames: "group_name_1, group_name_2",
      }),
      "it shows correct restricted group name"
    );
  });
});

acceptance("Share and Invite modal - mobile", function (needs) {
  needs.user();
  needs.mobileView();

  test("Topic footer mobile button", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#topic-footer-button-share-and-invite")
      .doesNotExist("the button doesn’t exist");

    const subject = selectKit(".topic-footer-mobile-dropdown");
    await subject.expand();
    await subject.selectRowByValue("share-and-invite");

    assert.dom(".share-topic-modal").exists("shows the modal");
  });
});

acceptance("Share url with badges disabled - desktop", function (needs) {
  needs.user();
  needs.settings({ enable_badges: false });

  needs.pretender((server, helper) => {
    server.get("/c/feature/find_by_slug.json", () =>
      helper.response(200, CategoryFixtures["/c/1/show.json"])
    );
  });

  test("topic footer button - badges disabled - desktop", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-button-share-and-invite");

    assert.notOk(
      query("input.invite-link").value.includes("?u=eviltrout"),
      "it doesn't add the username param when badges are disabled"
    );
  });
});

acceptance("With username in share links disabled - desktop", function (needs) {
  needs.user();
  needs.settings({ allow_username_in_share_links: false });

  needs.pretender((server, helper) => {
    server.get("/c/feature/find_by_slug.json", () =>
      helper.response(200, CategoryFixtures["/c/1/show.json"])
    );
  });

  test("topic footer button - username in share links disabled - desktop", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-button-share-and-invite");

    assert.notOk(
      query("input.invite-link").value.includes("?u=eviltrout"),
      "it doesn't add the username param when username in share links are disabled"
    );
  });
});
