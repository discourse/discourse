import { click, find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import AiArtifactShare from "discourse/plugins/discourse-ai/discourse/components/ai-artifact-share";

module("Integration | Component | AiArtifactShare", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.discourse_ai_enabled = true;
    this.siteSettings.ai_bot_enabled = true;
    this.siteSettings.ai_artifact_security = "strict";
    this.currentUser.can_share_ai_bot_conversations = true;
  });

  hooks.afterEach(() => sinon.restore());

  test("skips eligibility requests when settings or sharing capability rule out sharing", async function (assert) {
    let requests = 0;
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => {
        requests++;
        return response({ can_share: true, share: null });
      }
    );
    this.currentUser.can_share_ai_bot_conversations = false;
    await render(<template><AiArtifactShare @artifactId="12" /></template>);
    assert.strictEqual(
      requests,
      0,
      "users without sharing capability do not probe"
    );
    assert.dom(".ai-artifact-share__toggle").doesNotExist("share is hidden");

    this.currentUser.can_share_ai_bot_conversations = true;
    this.siteSettings.ai_artifact_security = "disabled";
    await render(<template><AiArtifactShare @artifactId="12" /></template>);
    assert.strictEqual(
      requests,
      0,
      "disabled artifacts never probe eligibility"
    );
  });

  test("checks eligibility based on capability even when memberships are not visible", async function (assert) {
    let requests = 0;
    this.currentUser.visibleGroups = [];
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => {
        requests++;
        return response({ can_share: true, share: null });
      }
    );

    await render(<template><AiArtifactShare @artifactId="12" /></template>);
    assert.strictEqual(
      requests,
      1,
      "hidden memberships do not block the probe"
    );
    assert
      .dom(".ai-artifact-share__toggle")
      .exists("server authorizes sharing");
  });

  test("does not offer sharing without server eligibility", async function (assert) {
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => response({ can_share: false, share: null })
    );

    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="12" />
      </template>
    );
    assert.dom(".ai-artifact-share__toggle").doesNotExist("share stays hidden");
  });

  test("stays silent when the passive eligibility check fails", async function (assert) {
    const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => response(404, { errors: ["Not found"] })
    );
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/13.json",
      () => response(500, { errors: ["Internal server error"] })
    );

    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="12" />
      </template>
    );
    assert
      .dom(".ai-artifact-share__toggle")
      .doesNotExist("a hidden artifact leaves sharing hidden");
    assert.false(
      alert.called,
      "a background miss does not interrupt the reader"
    );

    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="13" />
      </template>
    );
    assert
      .dom(".ai-artifact-share__toggle")
      .doesNotExist("a failing check leaves sharing hidden");
    assert.false(
      alert.called,
      "a background failure does not interrupt the reader"
    );
  });

  test("opens all share controls outside clipped cooked content", async function (assert) {
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () =>
        response({
          can_share: true,
          share: {
            share_key: "secret",
            url: "/artifact-shares/secret",
            version: 2,
          },
        })
    );

    await render(
      <template>
        <ModalContainer />
        <div class="cooked" style="overflow: hidden; height: 3em">
          <AiArtifactShare @artifactId="12" @artifactVersion="1" />
        </div>
      </template>
    );
    await click(".ai-artifact-share__toggle");

    assert
      .dom(".ai-artifact-share-modal", document)
      .exists("the share dialog renders through the modal container");
    assert.strictEqual(
      document.querySelector(".ai-artifact-share-modal").closest(".cooked"),
      null,
      "the dialog is not clipped by the cooked ancestor"
    );
    assert
      .dom(".ai-artifact-share-modal", document)
      .includesText(
        i18n("discourse_ai.ai_artifact.privacy_notice"),
        "explains privacy"
      );
    assert
      .dom(".ai-artifact-share-modal__link", document)
      .hasText("/artifact-shares/secret", "shows the actual share URL")
      .hasAttribute(
        "href",
        "/artifact-shares/secret",
        "the URL opens the shared artifact"
      );
    for (const label of [
      "Copy link",
      "Embed in post",
      "Embed on website",
      "Show in new tab",
      "Update pinned version",
      "Revoke link",
    ]) {
      assert
        .dom(".ai-artifact-share-modal__actions", document)
        .includesText(label, `${label} is available in the dialog`);
    }
    assert
      .dom(".ai-artifact-share-modal__embed-post", document)
      .hasAttribute(
        "title",
        i18n("discourse_ai.ai_artifact.embed_post_title"),
        "the post button explains copying code"
      );
    assert
      .dom(".ai-artifact-share-modal__embed-website", document)
      .hasAttribute(
        "title",
        i18n("discourse_ai.ai_artifact.embed_website_title"),
        "the website button explains copying HTML"
      );
    assert
      .dom(".ai-artifact-share-modal__actions a", document)
      .hasAttribute(
        "href",
        "/artifact-shares/secret",
        "new tab opens the share URL"
      );
    assert
      .dom(".ai-artifact-share__panel")
      .doesNotExist("no inline panel remains");
  });

  test("login-required forums explain that viewing requires sign-in", async function (assert) {
    this.siteSettings.login_required = true;
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => response({ can_share: true, share: null })
    );
    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="12" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    assert
      .dom(".ai-artifact-share-modal")
      .includesText(
        "Signed-in users with the link can view this version. Your conversation stays private.",
        "private forum has a truthful notice"
      );
    assert
      .dom(".ai-artifact-share-modal")
      .doesNotIncludeText("Anyone with the link", "public notice is not used");
  });

  test("copies a standalone share key for posts and the existing URL for websites", async function (assert) {
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () =>
        response({
          can_share: true,
          share: {
            share_key: "secret",
            url: "https://example.com/artifact-shares/secret",
            version: 2,
          },
        })
    );

    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="12" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    await click(".ai-artifact-share-modal__embed-post");
    await click(".ai-artifact-share-modal__embed-website");
    await click(".ai-artifact-share-modal__copy-link");

    assert.deepEqual(
      writeText.getCalls().map((call) => call.args[0]),
      [
        '[ai-artifact share="secret"]',
        '<iframe src="https://example.com/artifact-shares/secret" width="100%" height="600" frameborder="0"></iframe>',
        "https://example.com/artifact-shares/secret",
      ],
      "the post tag uses only the share key, while the website and link keep the supplied absolute URL"
    );
  });

  test("creates a standalone link immediately when Create link is clicked", async function (assert) {
    let creations = 0;
    let postedVersion;
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => response({ can_share: true, share: null })
    );
    pretender.post(
      "/discourse-ai/ai-bot/artifact-shares/12.json",
      (request) => {
        creations++;
        postedVersion = new URLSearchParams(request.requestBody).get("version");
        return response({
          share_key: "secret",
          url: "/artifact-shares/secret",
          version: 0,
        });
      }
    );

    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="12" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    assert.strictEqual(
      creations,
      0,
      "opening the modal does not publish anything"
    );
    assert
      .dom(".ai-artifact-share-modal")
      .includesText("conversation", "privacy is explained");

    await click(".ai-artifact-share-modal__create");
    assert.strictEqual(creations, 1, "the owner deliberately creates the link");
    assert.strictEqual(postedVersion, "0", "the original version is explicit");
    assert
      .dom(".ai-artifact-share-modal a[target='_blank']")
      .exists("new tab uses the share URL");
    await click(".ai-artifact-share-modal .modal-close");
    await click(".ai-artifact-share__toggle");
    assert
      .dom(".ai-artifact-share-modal__actions")
      .exists("reopening retains the newly created link");
  });

  test("keeps creation available when the server refuses a changed version", async function (assert) {
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () => response({ can_share: true, share: null })
    );
    pretender.post("/discourse-ai/ai-bot/artifact-shares/12.json", () =>
      response(409, { error: "Another version is already shared" })
    );

    await render(
      <template>
        <ModalContainer /><AiArtifactShare @artifactId="12" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    await click(".ai-artifact-share-modal__create");
    assert
      .dom(".ai-artifact-share-modal__create")
      .exists("a failed creation can be retried")
      .isNotDisabled("creation is available after the request finishes");
    assert
      .dom(".ai-artifact-share-modal__actions")
      .doesNotExist("copy controls stay hidden after a failed create");
  });

  test("revokes the link and keeps the create state when reopened", async function (assert) {
    let revocations = 0;
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () =>
        response({
          can_share: true,
          share: {
            share_key: "secret",
            url: "/artifact-shares/secret",
            version: 0,
          },
        })
    );
    pretender.delete("/discourse-ai/ai-bot/artifact-shares/secret.json", () => {
      revocations++;
      return response({});
    });

    await render(
      <template>
        <ModalContainer /><DialogHolder /><AiArtifactShare @artifactId="12" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    assert
      .dom(".ai-artifact-share-modal__revoke.btn-danger")
      .exists("destructive action is red");
    await click(".ai-artifact-share-modal__revoke");
    assert
      .dom("#dialog-title")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_standalone_title")
      );
    assert
      .dom(".dialog-body")
      .hasText(
        i18n("discourse_ai.ai_artifact.confirm_revoke_standalone_message")
      );
    assert.strictEqual(revocations, 0, "no deletion before confirmation");
    assert
      .dom(".ai-artifact-share-modal__copy-link")
      .isDisabled("copy is blocked while confirming");
    assert
      .dom(".ai-artifact-share-modal__update")
      .isDisabled("update is blocked while confirming");
    await click(".dialog-footer .btn-default");
    assert.strictEqual(revocations, 0, "cancel retains the link");
    assert.dom(".ai-artifact-share-modal__link").exists("link remains visible");
    await click(".ai-artifact-share-modal__revoke");
    await click(".dialog-footer .btn-danger");
    assert.strictEqual(revocations, 1, "confirmation revokes once");
    assert
      .dom(".ai-artifact-share-modal__create")
      .exists("creation becomes available without leaving the dialog");
    await click(".ai-artifact-share-modal .modal-close");
    await click(".ai-artifact-share__toggle");
    assert
      .dom(".ai-artifact-share-modal__create")
      .exists("the revoked link is not restored on reopening");
  });

  test("an in-flight pin update blocks copy and revoke until it completes", async function (assert) {
    let respond;
    let updates = 0;
    let revocations = 0;
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () =>
        response({
          can_share: true,
          share: {
            share_key: "secret",
            url: "/artifact-shares/secret",
            version: 0,
          },
        })
    );
    pretender.put("/discourse-ai/ai-bot/artifact-shares/secret.json", () => {
      updates++;
      return new Promise((resolve) => {
        respond = resolve;
      });
    });
    pretender.delete("/discourse-ai/ai-bot/artifact-shares/secret.json", () => {
      revocations++;
      return response({});
    });
    await render(
      <template>
        <ModalContainer /><DialogHolder /><AiArtifactShare @artifactId="12" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    find(".ai-artifact-share-modal__update").click();
    await waitUntil(() => updates === 1);
    assert
      .dom(".ai-artifact-share-modal__copy-link")
      .isDisabled("copy is blocked");
    assert
      .dom(".ai-artifact-share-modal__revoke")
      .isDisabled("revoke is blocked");
    find(".ai-artifact-share-modal__update").click();
    find(".ai-artifact-share-modal__revoke").click();
    assert.strictEqual(updates, 1, "a second update is not sent");
    assert.strictEqual(revocations, 0, "no concurrent revoke is sent");
    respond(
      response({
        share_key: "secret",
        url: "/artifact-shares/secret",
        version: 0,
      })
    );
    await settled();
    assert
      .dom(".ai-artifact-share-modal__copy-link")
      .isNotDisabled("copy returns when settled");
  });

  test("updates a link to the older version being viewed, not the newer version", async function (assert) {
    let updatedVersion;
    pretender.get(
      "/discourse-ai/ai-bot/artifact-shares/eligibility/12.json",
      () =>
        response({
          can_share: true,
          share: {
            share_key: "secret",
            url: "/artifact-shares/secret",
            version: 2,
          },
        })
    );
    pretender.put(
      "/discourse-ai/ai-bot/artifact-shares/secret.json",
      (request) => {
        updatedVersion = new URLSearchParams(request.requestBody).get(
          "version"
        );
        return response({
          share_key: "secret",
          url: "/artifact-shares/secret",
          version: 1,
        });
      }
    );

    await render(
      <template>
        <ModalContainer />
        <AiArtifactShare @artifactId="12" @artifactVersion="1" />
      </template>
    );
    await click(".ai-artifact-share__toggle");
    await click(".ai-artifact-share-modal__actions button:nth-of-type(4)");
    assert.strictEqual(
      updatedVersion,
      "1",
      "update pins the older viewed version"
    );
    assert
      .dom(".ai-artifact-share-modal__link")
      .hasText("/artifact-shares/secret", "pinning does not change the URL");
    assert.strictEqual(
      this.owner.lookup("service:toasts").activeToasts.at(-1)?.options.data
        .message,
      i18n("discourse_ai.ai_artifact.pin_updated"),
      "pin update shows a translated toast"
    );
  });
});
