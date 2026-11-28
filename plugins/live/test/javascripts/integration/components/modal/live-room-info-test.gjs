import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import LiveRoomInfo from "discourse/plugins/live/discourse/components/modal/live-room-info";

const ROLE_SELECT = ".live-room-info-modal__role-select";
const ROLE_CHOOSER = ".live-room-info-modal__role-chooser";

module("Integration | Component | Modal | LiveRoomInfo", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_new_select_controls = true;
    this.requests = [];

    pretender.get("/live/rooms/7/memberships", () =>
      response({
        memberships: [
          {
            id: 11,
            user_id: 2,
            role_name: "participant",
            user: {
              id: 2,
              username: "ravenmoor",
              avatar_template: "/a/{size}",
            },
          },
        ],
      })
    );
    pretender.put("/live/rooms/7/memberships/11", (request) => {
      this.requests.push(parsePostData(request.requestBody));
      return response({});
    });
    pretender.post("/live/rooms/7/memberships", (request) => {
      this.requests.push(parsePostData(request.requestBody));
      return response({});
    });

    this.showModal = async () => {
      const model = {
        room: {
          id: 7,
          slug: "night-ride",
          name: "Night ride",
          can_manage: true,
          public: false,
          room_type: "stage",
          creator_id: 1,
        },
      };
      await render(<template><ModalContainer /></template>);
      this.owner.lookup("service:modal").show(LiveRoomInfo, { model });
      await settled();
    };
  });

  test("changes a member's role", async function (assert) {
    await this.showModal();

    assert
      .dSelect(ROLE_SELECT)
      .hasName(
        i18n("live.room_info.members.participant"),
        "the member's role is shown"
      );

    await dSelect(ROLE_SELECT).open();

    assert
      .dSelect(ROLE_SELECT)
      .hasOptions(
        ["participant", "speaker", "moderator"],
        "a stage room offers the speaker role"
      );

    await dSelect(ROLE_SELECT).select("moderator");

    assert.deepEqual(
      this.requests,
      [{ role: "moderator" }],
      "the new role is saved"
    );
  });

  test("adds members with the picked role", async function (assert) {
    pretender.get("/u/search/users", () =>
      response({
        users: [
          {
            username: "wheelwright",
            name: "Wren",
            avatar_template: "/a/{size}",
          },
        ],
      })
    );
    await this.showModal();

    assert
      .dSelect(ROLE_CHOOSER)
      .hasName(
        i18n("live.room_info.members.participant"),
        "new members are participants by default"
      );

    await dSelect(ROLE_CHOOSER).open();
    await dSelect(ROLE_CHOOSER).select("speaker");

    const users = dSelect(".live-room-info-modal__user-chooser");
    await users.search("whe");
    await users.selectByName("wheelwright");
    await users.close();
    await click(".live-room-info-modal__add-btn");

    assert.deepEqual(
      this.requests,
      [{ username: "wheelwright", role: "speaker" }],
      "the member is added with the picked role"
    );
  });
});
