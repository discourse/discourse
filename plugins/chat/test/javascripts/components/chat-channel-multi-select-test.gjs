import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatChannelMultiSelect from "discourse/plugins/chat/discourse/components/chat-channel-multi-select";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

class TestTemplate extends Component {
  @tracked selection = this.args.selection || [];

  <template>
    <ChatChannelMultiSelect
      @initialIds={{@initialIds}}
      @selection={{this.selection}}
      @onChange={{fn (mut this.selection)}}
    />
  </template>
}

module(
  "Discourse Chat | Component | chat-channel-multi-select",
  function (hooks) {
    setupRenderingTest(hooks);

    test("@initialIds", async function (assert) {
      const channel = new ChatFabricators(getOwner(this)).channel();

      pretender.get("/chat/api/channels", () => {
        return response({
          channels: [
            { id: channel.id, title: channel.title, slug: channel.slug },
          ],
        });
      });

      await render(
        <template><TestTemplate @initialIds={{array channel.id}} /></template>
      );

      assert
        .dom(".d-multi-select-trigger__selection-label:nth-of-type(1)")
        .hasText(channel.title);
    });

    test("@selection", async function (assert) {
      const channel = new ChatFabricators(getOwner(this)).channel();

      pretender.get("/chat/api/channels", () => {
        return response({
          channels: [
            { id: channel.id, title: channel.title, slug: channel.slug },
          ],
        });
      });

      await render(
        <template><TestTemplate @selection={{array channel}} /></template>
      );

      assert
        .dom(".d-multi-select-trigger__selection-label:nth-of-type(1)")
        .hasText(channel.title);
    });
  }
);
