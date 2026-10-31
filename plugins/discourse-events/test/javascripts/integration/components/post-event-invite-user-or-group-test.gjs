import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import PostEventInviteUserOrGroup from "discourse/plugins/discourse-events/discourse/components/modal/post-event-invite-user-or-group";

module(
  "Integration | Component | Modal | PostEventInviteUserOrGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    test("with the new select controls, invites the picked users and groups", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      let searchParams;
      pretender.get("/u/search/users", (request) => {
        searchParams = request.queryParams;
        return response({
          users: [
            { username: "bob", name: "Bob", avatar_template: "/a/{size}" },
          ],
          groups: [{ name: "team", full_name: "The team" }],
        });
      });
      let data;
      pretender.post(
        "/discourse-post-event/events/7/invite.json",
        (request) => {
          data = parsePostData(request.requestBody);
          return response({});
        }
      );
      const model = { event: { id: 7 } };

      await render(<template><ModalContainer /></template>);
      this.owner
        .lookup("service:modal")
        .show(PostEventInviteUserOrGroup, { model });
      await settled();
      const invitees = dSelect(".d-modal .d-select");
      await invitees.search("bo");
      await invitees.selectByName("bob");
      await invitees.search("te");
      await invitees.selectByName("team");
      await invitees.close();
      await click(".d-modal__footer .btn-primary");

      assert.strictEqual(searchParams.include_messageable_groups, "true");
      assert.deepEqual(data["invites[]"], ["bob", "team"]);
    });
  }
);
