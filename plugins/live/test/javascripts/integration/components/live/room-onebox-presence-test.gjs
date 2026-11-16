import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LiveRoomOneboxPresence from "discourse/plugins/live/discourse/components/live/room-onebox-presence";

class LiveRoomsStub extends Service {
  @tracked rooms = [];

  roomBySlug(slug) {
    return this.rooms.find((room) => room.slug === slug);
  }
}

function participant(id) {
  return {
    id,
    username: `user${id}`,
    avatar_template: "/letter_avatar_proxy/v4/letter/u/aaaaaa/{size}.png",
  };
}

module("Integration | Component | Live | RoomOneboxPresence", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:live-rooms");
    this.owner.register("service:live-rooms", LiveRoomsStub);
    this.liveRooms = this.owner.lookup("service:live-rooms");
    this.data = { slug: "watercooler" };
  });

  test("renders nothing while the room is empty or unknown", async function (assert) {
    await render(
      <template><LiveRoomOneboxPresence @data={{this.data}} /></template>
    );
    assert.dom(".live-room-onebox__presence").doesNotExist("unknown room");

    this.liveRooms.rooms = [{ slug: "watercooler", active_participants: [] }];
    await settled();
    assert.dom(".live-room-onebox__presence").doesNotExist("empty room");
  });

  test("shows who is here and follows directory updates", async function (assert) {
    this.liveRooms.rooms = [
      { slug: "watercooler", active_participants: [participant(1)] },
    ];

    await render(
      <template><LiveRoomOneboxPresence @data={{this.data}} /></template>
    );

    assert
      .dom(".live-room-onebox__presence-label")
      .hasText("1 person here now");
    assert
      .dom(".live-room-onebox__presence-avatars .avatar")
      .exists({ count: 1 });

    this.liveRooms.rooms = [
      {
        slug: "watercooler",
        active_participants: [1, 2, 3, 4, 5, 6, 7].map(participant),
      },
    ];
    await settled();

    assert
      .dom(".live-room-onebox__presence-label")
      .hasText("7 people here now");
    assert
      .dom(".live-room-onebox__presence-avatars .avatar")
      .exists({ count: 5 }, "caps the avatars");
  });
});
