import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Category Banners", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/c/test-read-only-without-banner/5/l/latest.json", () => {
      return helper.response(
        DiscoveryFixtures["/latest_can_create_topic.json"]
      );
    });
    server.get("/c/test-read-only-with-banner/6/l/latest.json", () => {
      return helper.response(
        DiscoveryFixtures["/latest_can_create_topic.json"]
      );
    });
  });
  needs.site({
    categories: [
      {
        id: 5,
        name: "test read only without banner",
        slug: "test-read-only-without-banner",
        permission: 1,
      },
      {
        id: 6,
        name: "test read only with banner",
        slug: "test-read-only-with-banner",
        permission: null,
        read_only_banner:
          "You need to video yourself <div class='inner'>doing</div> the secret handshake to post here",
      },
    ],
  });

  test("Does not display category banners when not set", async function (assert) {
    await visit("/c/test-read-only-without-banner");

    await click("#create-topic");
    assert.dom(".dialog-body").doesNotExist("does not pop up a modal");
    assert
      .dom(".category-read-only-banner")
      .doesNotExist("does not show a banner");
  });

  test("Displays category banners when set", async function (assert) {
    await visit("/c/test-read-only-with-banner");

    await click("#create-topic");
    assert.dom(".dialog-body").exists("pops up a modal");

    await click(".dialog-footer .btn-primary");
    assert.dom(".dialog-body").doesNotExist("closes the modal");
    assert.dom(".category-read-only-banner").exists("shows a banner");
    assert
      .dom(".category-read-only-banner .inner")
      .exists({ count: 1 }, "allows staff to embed html in the message");
  });
});

acceptance("Anonymous Category Banners", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/c/test-read-only-with-banner/6/l/latest.json", () => {
      return helper.response(
        DiscoveryFixtures["/latest_can_create_topic.json"]
      );
    });
  });
  needs.site({
    categories: [
      {
        id: 6,
        name: "test read only with banner",
        slug: "test-read-only-with-banner",
        permission: null,
        read_only_banner:
          "You need to video yourself doing the secret handshake to post here",
      },
    ],
  });

  test("Does not display category banners when set", async function (assert) {
    await visit("/c/test-read-only-with-banner");
    assert
      .dom(".category-read-only-banner")
      .doesNotExist("does not show a banner");
  });
});
