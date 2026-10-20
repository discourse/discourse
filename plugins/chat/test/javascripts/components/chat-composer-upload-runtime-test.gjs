import { render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadUppy, { resetUppyForTesting } from "discourse/lib/load-uppy";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import Channel from "discourse/plugins/chat/discourse/components/chat/composer/channel";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

module("Component | chat-composer upload runtime", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetUppyForTesting();
  });

  test("uploads mount once the upload runtime has loaded", async function (assert) {
    pretender.get("/emojis.json", () => [200, [], {}]);
    this.siteSettings.chat_allow_uploads = true;
    this.channel = ChatChannel.create({ chatable_type: "Category", id: 1 });
    this.dropZone = document.createElement("div");

    const runtime = await loadUppy();
    let finishLoading;
    const loading = new Promise((resolve) => (finishLoading = resolve));
    resetUppyForTesting({ importer: () => loading.then(() => runtime) });

    const rendering = render(
      <template>
        <Channel @channel={{this.channel}} @uploadDropZone={{this.dropZone}} />
      </template>
    );
    await waitFor(".chat-composer__input");
    assert
      .dom(".chat-composer-uploads")
      .doesNotExist("themes extending the uploads wait for the runtime");

    finishLoading();
    await rendering;
    assert
      .dom(".chat-composer-uploads")
      .exists("the uploads mount once the runtime loads");
  });
});
