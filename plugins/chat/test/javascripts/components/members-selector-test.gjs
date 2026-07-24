import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import MembersSelector from "discourse/plugins/chat/discourse/components/chat/message-creator/members-selector";
import ChatChatable from "discourse/plugins/chat/discourse/models/chat-chatable";

module("Component | MembersSelector", function (hooks) {
  setupRenderingTest(hooks);

  test("lists a group result even when a selected user shares its numeric id", async function (assert) {
    // A user and a group can have the same numeric id (different tables). The
    // selected member here is `u-42`; the searched group is `g-42`. They must
    // not be treated as the same chatable.
    pretender.get("/chat/api/chatables", () =>
      response({
        users: [],
        groups: [
          {
            identifier: "g-42",
            type: "group",
            match_quality: 1,
            model: {
              id: 42,
              name: "team",
              can_chat: true,
              chat_enabled_user_count: 3,
            },
          },
        ],
        direct_message_channels: [],
        category_channels: [],
      })
    );

    const members = [
      ChatChatable.createUser({
        id: 42,
        username: "alice",
        has_chat_enabled: true,
      }),
    ];
    const noop = () => {};

    await render(
      <template>
        <MembersSelector
          @members={{members}}
          @membersCount={{0}}
          @maxReached={{false}}
          @onChange={{noop}}
          @close={{noop}}
          @cancel={{noop}}
        />
      </template>
    );

    await fillIn(".chat-message-creator__members-input", "team");

    assert
      .dom(".chat-message-creator__list-item[data-identifier='g-42']")
      .exists(
        "the group row is listed despite the id collision with a selected user"
      );
  });
});
