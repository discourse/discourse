import { click, find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Group Card", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/groups/support/members.json", () =>
      helper.response({
        members: [],
        owners: [],
        meta: { total: 0, limit: 10, offset: 0 },
      })
    );
  });

  test("opens for group links and cooked group mentions", async function (assert) {
    await visit("/t/internationalization-localization/280");

    find("#main-outlet").insertAdjacentHTML(
      "beforeend",
      '<a class="user-group trigger-group-card" data-group-card="discourse" href="/g/discourse">Discourse</a>' +
        '<a class="mention-group" href="/g/discourse">@discourse</a>' +
        '<a class="mention-group" data-group-card="support" href="/g/support">@support</a>'
    );

    await click('a[data-group-card="discourse"]');

    assert
      .dom(".group-card.show .group-page-link")
      .exists({ count: 1 }, "opens one group card")
      .hasText("discourse", "loads the group identified by the data attribute");

    await click("#main-outlet");
    await click('a.mention-group[href="/g/discourse"]');

    assert
      .dom(".group-card.show .group-page-link")
      .exists({ count: 1 }, "opens one card for a cooked mention")
      .hasText("discourse", "derives the group from the cooked mention text");

    await click("#main-outlet");
    await click('a.mention-group[data-group-card="support"]');

    assert
      .dom(".group-card.show .group-page-link")
      .exists({ count: 1 }, "opens one card when both selectors match")
      .hasText("support", "prefers the authoritative group data attribute");
  });

  test("does not intercept modifier-click navigation", async function (assert) {
    await visit("/t/internationalization-localization/280");

    find("#main-outlet").insertAdjacentHTML(
      "beforeend",
      '<a class="user-group trigger-group-card" data-group-card="discourse" href="/g/discourse">Discourse</a>'
    );

    const link = find('a[data-group-card="discourse"]');
    const event = new MouseEvent("click", {
      bubbles: true,
      cancelable: true,
      ctrlKey: true,
    });

    assert.true(
      link.dispatchEvent(event),
      "leaves native navigation unprevented"
    );
    await settled();

    assert.dom(".group-card.show").doesNotExist("does not open the group card");
  });
});
