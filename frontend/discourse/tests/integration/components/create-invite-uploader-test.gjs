import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import {
  click,
  find,
  render,
  triggerEvent,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import CreateInviteUploader from "discourse/components/create-invite-uploader";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | CreateInviteUploader", function (hooks) {
  setupRenderingTest(hooks);

  test("yields the upload state", async function (assert) {
    let release;
    const held = new Promise((resolve) => (release = resolve));
    pretender.post("/invites/upload_csv.json", async () => {
      await held;
      return response({});
    });

    await render(
      <template>
        <CreateInviteUploader as |uploader setElement|>
          <input type="file" {{didInsert setElement}} />
          <span class="uploading">{{if uploader.uploading "yes" "no"}}</span>
          <span class="uploaded">{{if uploader.uploaded "yes" "no"}}</span>
          <button type="button" {{on "click" uploader.startUpload}}>
            upload
          </button>
        </CreateInviteUploader>
      </template>
    );

    await triggerEvent("input[type='file']", "change", {
      files: [createFile("invites.csv", "text/csv")],
    });
    click("button");
    await waitUntil(() => find(".uploading").textContent === "yes");

    assert.dom(".uploading").hasText("yes", "reports an upload in progress");
    assert.dom(".uploaded").hasText("no");

    release();
    await waitUntil(() => find(".uploaded").textContent === "yes");

    assert.dom(".uploading").hasText("no", "reports the upload finished");
    assert.dom(".uploaded").hasText("yes", "reports the upload succeeded");
  });
});
