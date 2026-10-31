import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ArchiveChannel from "discourse/plugins/chat/discourse/components/chat/modal/archive-channel";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | <Chat::Modal::ArchiveChannel>", function (hooks) {
  setupRenderingTest(hooks);

  test("channel title is escaped in instructions correctly", async function (assert) {
    this.channel = new ChatFabricators(getOwner(this)).channel({
      title: `<script>someeviltitle</script>`,
    });

    await render(
      <template>
        <ArchiveChannel @inline={{true}} @model={{hash channel=this.channel}} />
      </template>
    );

    assert
      .dom(".chat-modal-archive-channel")
      .includesHtml("&lt;script&gt;someeviltitle&lt;/script&gt;");
  });

  test("archiving to a new topic sends the tags picked in the tag chooser", async function (assert) {
    getOwner(this).lookup("service:site").can_create_tag = true;
    const channel = new ChatFabricators(getOwner(this)).channel({ id: 77 });
    const closeModal = () => {};
    let body;

    pretender.post("/chat/api/channels/77/archives", (request) => {
      body = new URLSearchParams(request.requestBody);
      return response({});
    });

    await render(
      <template>
        <ArchiveChannel
          @closeModal={{closeModal}}
          @inline={{true}}
          @model={{hash channel=channel}}
        />
      </template>
    );

    await fillIn("#split-topic-name", "An archive topic with a long title");

    const tagChooser = selectKit(".chat-to-topic-selector .tag-chooser");
    await tagChooser.expand();
    await tagChooser.fillInFilter("mon");
    await tagChooser.selectRowByName("monkey");
    if (!tagChooser.isExpanded()) {
      await tagChooser.expand();
    }
    await tagChooser.fillInFilter("dog");
    await tagChooser.selectRowByName("dog");

    await click("#chat-confirm-archive-channel");

    assert.strictEqual(body?.get("archive[type]"), "new_topic");
    assert.deepEqual(
      body?.getAll("archive[tags][]"),
      ["monkey", "dog"],
      "sends the picked tags in selection order"
    );
  });

  test("archiving to a new topic sends the tags picked with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    getOwner(this).lookup("service:site").can_create_tag = true;
    const channel = new ChatFabricators(getOwner(this)).channel({ id: 77 });
    const closeModal = () => {};
    let body;

    pretender.post("/chat/api/channels/77/archives", (request) => {
      body = new URLSearchParams(request.requestBody);
      return response({});
    });

    await render(
      <template>
        <ArchiveChannel
          @closeModal={{closeModal}}
          @inline={{true}}
          @model={{hash channel=channel}}
        />
      </template>
    );

    await fillIn("#split-topic-name", "An archive topic with a long title");

    const tagChooser = dSelect(".chat-to-topic-selector .tag-chooser");
    await tagChooser.search("mon");
    await tagChooser.selectByName("monkey");
    await tagChooser.search("dog");
    await tagChooser.selectByName("dog");
    await tagChooser.close();

    await click("#chat-confirm-archive-channel");

    assert.strictEqual(body?.get("archive[type]"), "new_topic");
    assert.deepEqual(
      body?.getAll("archive[tags][]"),
      ["monkey", "dog"],
      "sends the picked tags in selection order"
    );
  });
});
