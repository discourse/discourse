import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import FlagsReorderable from "discourse/admin/components/admin-config-areas/flags-reorderable";
import { SYSTEM_FLAG_IDS } from "discourse/admin/lib/constants";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { moveVia } from "discourse/tests/helpers/ui-kit/reorderable-list-helper";

module(
  "Integration | Component | AdminConfigAreas | FlagsReorderable",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const flags = [
        { id: SYSTEM_FLAG_IDS.notify_user, name: "Message" },
        { id: SYSTEM_FLAG_IDS.off_topic, name: "Off-Topic" },
        { id: SYSTEM_FLAG_IDS.inappropriate, name: "Inappropriate" },
        { id: SYSTEM_FLAG_IDS.spam, name: "Spam" },
        { id: SYSTEM_FLAG_IDS.illegal, name: "Illegal" },
      ].map((flag) => ({
        ...flag,
        name_key: flag.name.toLowerCase(),
        description: "",
        enabled: true,
        is_flag: true,
        system: true,
      }));
      getOwner(this).lookup("service:site").set("post_action_types", flags);

      // The endpoint as the server implements it: the flag lands on a position
      // among the flags that can move.
      this.serverOrder = flags.slice(1).map((flag) => flag.name);
      this.serverRefuses = false;
      pretender.put("/admin/config/flags/:id/move", (request) => {
        if (this.serverRefuses) {
          return response(422, { errors: ["refused"] });
        }
        const name = flags.find(
          (flag) => flag.id === Number(request.params.id)
        ).name;
        const position = Number(
          new URLSearchParams(request.requestBody).get("position")
        );
        this.serverOrder.splice(this.serverOrder.indexOf(name), 1);
        this.serverOrder.splice(position, 0, name);
        return response(204, {});
      });
    });

    function displayedOrder() {
      return [...document.querySelectorAll(".admin-flag-item__name")].map(
        (element) => element.textContent.trim()
      );
    }

    test("a move across several rows reaches the server", async function (assert) {
      await render(<template><DMenus /><FlagsReorderable /></template>);

      await moveVia(SYSTEM_FLAG_IDS.off_topic, "bottom");

      assert.deepEqual(
        this.serverOrder,
        ["Inappropriate", "Spam", "Illegal", "Off-Topic"],
        "the server moved the flag as far as the list did"
      );
      assert.deepEqual(
        displayedOrder(),
        ["Message", ...this.serverOrder],
        "the list shows the order the server holds"
      );
    });

    test("a move the server refuses is undone", async function (assert) {
      this.serverRefuses = true;
      await render(<template><DMenus /><FlagsReorderable /></template>);

      await moveVia(SYSTEM_FLAG_IDS.illegal, "top");

      assert.deepEqual(
        displayedOrder(),
        ["Message", "Off-Topic", "Inappropriate", "Spam", "Illegal"],
        "the list is back in the order the server holds"
      );
      assert
        .dom(".admin-flag-item.illegal")
        .hasClass("saved", "the row is no longer pending");
    });
  }
);
