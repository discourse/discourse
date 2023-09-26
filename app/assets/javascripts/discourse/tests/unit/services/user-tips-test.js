import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Unit | Service | user-tips", function (needs) {
  needs.user();

  test("hideUserTipForever() makes a single request", async function (assert) {
    const site = getOwnerWithFallback(this).lookup("service:site");
    site.set("user_tips", { first_notification: 1 });
    const userTips = getOwnerWithFallback(this).lookup("service:user-tips");

    let requestsCount = 0;
    pretender.put("/u/eviltrout.json", () => {
      requestsCount += 1;
      return response(200, {
        user: {
          user_option: {
            seen_popups: [1],
          },
        },
      });
    });

    await userTips.hideUserTipForever("first_notification");
    assert.strictEqual(requestsCount, 1);

    await userTips.hideUserTipForever("first_notification");
    assert.strictEqual(requestsCount, 1);
  });
});
