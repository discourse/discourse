import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import LiveInviteUsers from "discourse/plugins/live/discourse/components/modal/live-invite-users";

module("Integration | Component | Modal | LiveInviteUsers", function (hooks) {
  setupRenderingTest(hooks);

  test("with the new select controls, invites the picked users but never offers the current user", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const currentUser = this.owner.lookup("service:current-user");
    pretender.get("/live/rooms/4/invites/suggestions", () =>
      response({ suggestions: [] })
    );
    pretender.get("/u/search/users", () =>
      response({
        users: [
          { username: currentUser.username, avatar_template: "/a/{size}" },
          { username: "bob", name: "Bob", avatar_template: "/a/{size}" },
        ],
      })
    );
    let data;
    pretender.post("/live/rooms/4/invites", (request) => {
      data = parsePostData(request.requestBody);
      return response({ invited_usernames: ["bob"], skipped_usernames: [] });
    });
    const model = { room: { id: 4, slug: "standup", name: "Standup" } };

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(LiveInviteUsers, { model });
    await settled();

    const users = dSelect(".live-invite-modal .d-select");
    await users.search("b");
    assert
      .dom(`.d-select__option[data-name='${currentUser.username}']`)
      .doesNotExist("the current user is not offered");
    await users.selectByName("bob");
    await users.close();
    await click(".live-invite-modal__send");

    assert.deepEqual(data["usernames[]"], ["bob"]);
  });
});
