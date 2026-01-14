import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Service | user-tips", function (hooks) {
  setupTest(hooks);

  test("hideUserTipForever() makes a single request", async function (assert) {
    logIn(this.owner);

    const site = getOwner(this).lookup("service:site");
    site.set("user_tips", { first_notification: 1 });

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

    const userTips = getOwner(this).lookup("service:user-tips");
    await userTips.hideUserTipForever("first_notification");
    assert.strictEqual(requestsCount, 1);

    await userTips.hideUserTipForever("first_notification");
    assert.strictEqual(requestsCount, 1);
  });
});
