import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("Site Banner", function () {
  test("shows and hides correctly", async function (assert) {
    await visit("/");

    assert.dom("#banner").doesNotExist();

    await publishToMessageBus("/site/banner", {
      html: "hello world",
      key: 12,
      url: "/t/12",
    });

    assert.dom("#banner #banner-content").hasText("hello world");

    await publishToMessageBus("/site/banner", null);

    assert.dom("#banner").doesNotExist();
  });
});
