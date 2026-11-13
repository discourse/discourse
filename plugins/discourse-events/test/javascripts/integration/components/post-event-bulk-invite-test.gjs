import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import PostEventBulkInvite from "discourse/plugins/discourse-events/discourse/components/modal/post-event-bulk-invite";

module(
  "Integration | Component | Modal | PostEventBulkInvite",
  function (hooks) {
    setupRenderingTest(hooks);

    test("with the new select controls, a public event invites the picked username", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      pretender.get("/u/search/users", () =>
        response({
          users: [
            { username: "bob", name: "Bob", avatar_template: "/a/{size}" },
          ],
        })
      );
      let body;
      pretender.post(
        "/discourse-post-event/events/7/bulk-invite.json",
        (request) => {
          body = JSON.parse(request.requestBody);
          return response({ success: true });
        }
      );
      const model = { event: { id: 7, isPublic: true } };

      await render(<template><ModalContainer /></template>);
      this.owner.lookup("service:modal").show(PostEventBulkInvite, { model });
      await settled();
      const identifier = dSelect(".bulk-invite-identifier");
      await identifier.search("bo");
      await identifier.selectByName("bob");
      await click(".send-bulk-invites");

      assert.strictEqual(body.invitees[0].identifier, "bob");
    });
  }
);
