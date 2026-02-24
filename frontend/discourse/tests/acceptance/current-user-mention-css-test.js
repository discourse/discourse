import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Current User Mention CSS", function (needs) {
  needs.user({ username: "eviltrout" });

  test("css is generated for current user mentions", async function (assert) {
    await visit("/");
    const cssTag = document.querySelector("style#current-user-mention-css");
    assert
      .dom(cssTag)
      .hasText(
        `.mention[href="/u/eviltrout"] { background: var(--tertiary-400); }`
      );
  });
});
