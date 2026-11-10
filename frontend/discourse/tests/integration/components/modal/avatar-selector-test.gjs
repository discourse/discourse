import {
  click,
  find,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AvatarSelectorModal from "discourse/components/modal/avatar-selector";
import ModalContainer from "discourse/components/modal-container";
import { restoreBaseUri, setupURL } from "discourse/lib/get-url";
import User from "discourse/models/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

async function showAvatarSelector(context, model) {
  await render(<template><ModalContainer /></template>);
  context.owner.lookup("service:modal").show(AvatarSelectorModal, { model });
  await settled();
}

module("Integration | Component | Modal | AvatarSelector", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  hooks.afterEach(() => restoreBaseUri());

  test("retained avatar previews use the authenticated site origin with a CDN configured", async function (assert) {
    setupURL(
      "https://cdn.example.com",
      "https://forum.example.com/forum",
      "/forum"
    );
    this.siteSettings.gravatar_enabled = true;
    this.siteSettings.selectable_avatars_mode = "disabled";
    const template = (id) =>
      `/forum/user_avatar/default/jane/{size}/${id}_2.png`;
    const model = {
      user: User.create({
        username: "jane",
        can_upload_avatar: true,
        avatar_template: template(1),
        gravatar_avatar_template: template(2),
        custom_avatar_template: template(3),
        associated_account_avatars: [
          {
            id: 1,
            name: "provider",
            upload_id: 4,
            avatar_template: template(4),
          },
        ],
      }),
    };

    await showAvatarSelector(this, model);

    for (const [choice, id] of [
      ["gravatar", 2],
      ["upload", 3],
      ["associated-account", 4],
    ]) {
      assert
        .dom(`.avatar-choice--${choice} img`)
        .hasAttribute(
          "src",
          new RegExp(
            `^https://forum\\.example\\.com/forum/user_avatar/default/jane/\\d+/${id}_2\\.png$`
          )
        );
    }
  });

  test("deferred file selection can be cancelled without changing the saved selection", async function (assert) {
    const initialFile = new File(["initial"], "initial.png", {
      type: "image/png",
    });
    const selection = { file: initialFile };
    const onSelect = sinon.spy();
    const model = {
      deferSave: true,
      canUploadAvatar: true,
      selection,
      onSelect,
    };

    await showAvatarSelector(this, model);

    assert
      .dom(".avatar-choice--upload img")
      .hasAttribute(
        "src",
        /^blob:/,
        "the saved file is previewed on reopening"
      );
    assert.dom("#uploaded-avatar").isChecked("the pending file is selected");
    assert
      .dom(".avatar-choice--gravatar")
      .doesNotExist("Gravatar requires an account");

    const replacement = new File(["replacement"], "replacement.png", {
      type: "image/png",
    });
    const transfer = new DataTransfer();
    transfer.items.add(replacement);
    find("#deferred-avatar-upload").files = transfer.files;
    await triggerEvent("#deferred-avatar-upload", "change");
    await click(".d-modal-cancel");

    assert
      .dom(".avatar-selector-modal")
      .doesNotExist("cancel closes the modal");
    assert.true(onSelect.notCalled, "cancel does not save a selection");
    assert.strictEqual(
      selection.file,
      initialFile,
      "the caller retains its original file"
    );
  });

  test("deferred preset selection waits for Save even when custom avatars are disabled", async function (assert) {
    this.siteSettings.selectable_avatars_mode = "no_one";
    this.siteSettings.selectable_avatars = ["/preset.png"];
    const onSelect = sinon.spy();
    const model = { deferSave: true, onSelect };

    await showAvatarSelector(this, model);
    await click(".selectable-avatar");

    assert.true(onSelect.notCalled, "choosing a preset does not save it");
    assert
      .dom(".avatar-selector-modal")
      .exists("the modal stays open until saved");
    assert
      .dom(".selectable-avatar")
      .hasAttribute("aria-current", "true", "the chosen preset is marked");
    await click(".btn-primary");
    assert.deepEqual(
      onSelect.firstCall.args,
      [{ url: "/preset.png" }],
      "Save returns the chosen preset to the caller"
    );
    assert.dom(".avatar-selector-modal").doesNotExist("Save closes the modal");
  });

  test("deferred selection can return to the system avatar", async function (assert) {
    const onSelect = sinon.spy();
    const model = {
      deferSave: true,
      canUploadAvatar: true,
      selection: {
        file: new File(["avatar"], "avatar.png", { type: "image/png" }),
      },
      onSelect,
    };

    await showAvatarSelector(this, model);
    assert
      .dom(".avatar-selector__placeholder .d-icon-user")
      .exists("the system avatar is neutral before a username is chosen");
    await click("#system-avatar");
    await click(".btn-primary");

    assert.deepEqual(
      onSelect.firstCall.args,
      [null],
      "Save clears the pending avatar"
    );
  });

  for (const trustLevel of [0, 1, 2, 3, 4]) {
    test(`deferred uploads respect the prospective trust level ${trustLevel}`, async function (assert) {
      this.siteSettings.selectable_avatars_mode = "tl2";
      await showAvatarSelector(this, {
        deferSave: true,
        canUploadAvatar: true,
        trustLevel,
      });

      if (trustLevel >= 2) {
        assert.dom("#deferred-avatar-upload").exists();
      } else {
        assert.dom("#deferred-avatar-upload").doesNotExist();
      }
    });
  }

  test("normal saving persists the selected avatar to the account", async function (assert) {
    const onAvatarChange = sinon.spy();
    const model = {
      user: User.create({
        username: "jane",
        avatar_template: "/custom.png",
        system_avatar_template: "/letter.png",
      }),
      onAvatarChange,
    };
    pretender.put("/u/jane/preferences/avatar/pick", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("type"),
        "system",
        "the normal picker saves to the account"
      );
      return response({ success: "OK" });
    });

    await showAvatarSelector(this, model);
    await click("#system-avatar");
    await click(".btn-primary");

    assert.true(
      onAvatarChange.calledOnce,
      "the caller is notified after saving"
    );
    assert
      .dom(".avatar-selector-modal")
      .doesNotExist("the picker closes after saving");
    assert
      .dom("#deferred-avatar-upload")
      .doesNotExist("normal mode does not offer a deferred upload");
  });
});
