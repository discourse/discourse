import { getOwner } from "@ember/owner";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  response,
  TOO_MANY_REQUESTS,
} from "discourse/tests/helpers/create-pretender";
import ChatRouteChannelInfoMembers from "discourse/plugins/chat/discourse/components/chat/routes/channel-info-members";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

const CHANNEL_ID = 1;

module("Component | ChatRouteChannelInfoMembers", function (hooks) {
  setupRenderingTest(hooks);

  test("ends the loading slider when loading members fails", async function (assert) {
    pretender.get(`/chat/api/channels/${CHANNEL_ID}/memberships`, () =>
      response(TOO_MANY_REQUESTS, { errors: ["Slow down"] })
    );

    const channel = new ChatFabricators(getOwner(this)).channel({
      id: CHANNEL_ID,
    });

    await render(
      <template><ChatRouteChannelInfoMembers @channel={{channel}} /></template>
    );

    await fillIn(".c-channel-members__filter input", "bob");

    assert.false(
      getOwner(this).lookup("service:loading-slider").loading,
      "the loading bar is not left running"
    );
  });
});
