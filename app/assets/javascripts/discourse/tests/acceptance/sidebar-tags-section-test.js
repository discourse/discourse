import I18n from "I18n";

import { click, currentURL, visit } from "@ember/test-helpers";

import {
  acceptance,
  conditionalTest,
  exists,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { isLegacyEmber } from "discourse-common/config/environment";
import discoveryFixture from "discourse/tests/fixtures/discovery-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Sidebar - Tags section - tagging disabled", function (needs) {
  needs.settings({
    tagging_enabled: false,
  });

  needs.user({ experimental_sidebar_enabled: true });

  conditionalTest(
    "tags section is not shown",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.ok(
        !exists(".sidebar-section-tags"),
        "does not display the tags section"
      );
    }
  );
});

acceptance("Sidebar - Tags section", function (needs) {
  needs.settings({
    tagging_enabled: true,
  });

  needs.user({
    experimental_sidebar_enabled: true,
    tracked_tags: ["tag1"],
    watched_tags: ["tag2", "tag3"],
    watching_first_post_tags: [],
  });

  needs.pretender((server, helper) => {
    server.get("/tag/:tagId/notifications", (request) => {
      return helper.response({
        tag_notification: { id: request.params.tagId },
      });
    });

    ["latest", "top", "new", "unread"].forEach((type) => {
      server.get(`/tag/:tagId/l/${type}.json`, () => {
        return helper.response(
          cloneJSON(discoveryFixture["/tag/important/l/latest.json"])
        );
      });
    });
  });

  conditionalTest(
    "clicking on section header link",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");
      await click(".sidebar-section-tags .sidebar-section-header-link");

      assert.strictEqual(
        currentURL(),
        "/tags",
        "it should transition to the tags page"
      );
    }
  );

  conditionalTest(
    "section content when user does not have any tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      updateCurrentUser({
        tracked_tags: [],
        watched_tags: [],
        watching_first_post_tags: [],
      });

      await visit("/");

      assert.strictEqual(
        query(
          ".sidebar-section-tags .sidebar-section-message"
        ).textContent.trim(),
        I18n.t("sidebar.sections.tags.no_tracked_tags"),
        "the no tracked tags message is displayed"
      );
    }
  );

  conditionalTest(
    "tag section links for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit("/");

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link").length,
        3,
        "3 section links under the section"
      );

      assert.strictEqual(
        query(".sidebar-section-link-tag1").textContent.trim(),
        "tag1",
        "displays the tag1 name for the link text"
      );

      assert.strictEqual(
        query(".sidebar-section-link-tag2").textContent.trim(),
        "tag2",
        "displays the tag2 name for the link text"
      );

      assert.strictEqual(
        query(".sidebar-section-link-tag3").textContent.trim(),
        "tag3",
        "displays the tag3 name for the link text"
      );

      await click(".sidebar-section-link-tag1");

      assert.strictEqual(
        currentURL(),
        "/tag/tag1",
        "it should transition to tag1's topics discovery page"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-tag1.active`),
        "the tag1 section link is marked as active"
      );

      await click(".sidebar-section-link-tag2");

      assert.strictEqual(
        currentURL(),
        "/tag/tag2",
        "it should transition to tag2's topics discovery page"
      );

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(`.sidebar-section-link-tag2.active`),
        "the tag2 section link is marked as active"
      );
    }
  );

  conditionalTest(
    "visiting tag discovery top route for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/top`);

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-link-tag1.active"),
        "the tag1 section link is marked as active for the top route"
      );
    }
  );

  conditionalTest(
    "visiting tag discovery new route for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/new`);

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-link-tag1.active"),
        "the tag1 section link is marked as active for the new route"
      );
    }
  );

  conditionalTest(
    "visiting tag discovery unread route for tracked tags",
    !isLegacyEmber(),
    async function (assert) {
      await visit(`/tag/tag1/l/unread`);

      assert.strictEqual(
        queryAll(".sidebar-section-tags .sidebar-section-link.active").length,
        1,
        "only one link is marked as active"
      );

      assert.ok(
        exists(".sidebar-section-link-tag1.active"),
        "the tag1 section link is marked as active for the unread route"
      );
    }
  );
});
