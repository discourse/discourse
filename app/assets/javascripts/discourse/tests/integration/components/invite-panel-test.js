import { set } from "@ember/object";
import { click, fillIn } from "@ember/test-helpers";
import User from "discourse/models/user";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | invite-panel", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("shows the invite link after it is generated", {
    template: hbs`{{invite-panel panel=panel}}`,

    beforeEach() {
      pretender.get("/u/search/users", () => {
        return [200, { "Content-Type": "application/json" }, { users: [] }];
      });

      pretender.post("/invites", () => {
        return [
          200,
          { "Content-Type": "application/json" },
          {
            link: "http://example.com/invites/92c297e886a0ca03089a109ccd6be155",
          },
        ];
      });

      set(this.currentUser, "details", { can_invite_via_email: true });
      this.set("panel", {
        id: "invite",
        model: { inviteModel: User.create(this.currentUser) },
      });
    },

    async test(assert) {
      const input = selectKit(".invite-user-input");
      await input.expand();
      await fillIn(".invite-user-input .filter-input", "eviltrout@example.com");
      await input.selectRowByValue("eviltrout@example.com");
      assert.ok(!exists(".send-invite:disabled"));
      await click(".generate-invite-link");
      assert.equal(
        find(".invite-link-input")[0].value,
        "http://example.com/invites/92c297e886a0ca03089a109ccd6be155"
      );
    },
  });
});
