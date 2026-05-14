import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import EmbedAuthFlowModal from "discourse/components/modal/embed-auth-flow";
import EmbedMode from "discourse/lib/embed-mode";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

const SESSION_KEY = "discourse:embed:auth-flow-state";
const SESSION_KEY_INTENT = "discourse:embed:auth-flow-intent";

function buildService(owner) {
  // Re-look up so a fresh instance runs `init` after we have set
  // EmbedMode.enabled and the site setting.
  owner.unregister("service:embed-auth-flow");
  return owner.lookup("service:embed-auth-flow");
}

function modalKind(stub, callIndex = 0) {
  return stub.getCall(callIndex).args[1]?.model?.kind;
}

function modalOnConfirm(stub, callIndex = 0) {
  return stub.getCall(callIndex).args[1]?.model?.onConfirm;
}

module("Unit | Service | embed-auth-flow", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.modalService = this.owner.lookup("service:modal");

    this.originalEmbedMode = EmbedMode.enabled;
    EmbedMode.enabled = true;
    this.siteSettings.embed_full_app_signin_flow = true;

    sessionStorage.removeItem(SESSION_KEY);
    sessionStorage.removeItem(SESSION_KEY_INTENT);

    this.modalShow = sinon.stub(this.modalService, "show");
    this.windowOpen = sinon
      .stub(window, "open")
      .returns({ closed: false, close: sinon.stub() });
  });

  hooks.afterEach(function () {
    EmbedMode.enabled = this.originalEmbedMode;
    sessionStorage.removeItem(SESSION_KEY);
    sessionStorage.removeItem(SESSION_KEY_INTENT);
  });

  test("isActive requires embed mode and the site setting", function (assert) {
    let service = buildService(this.owner);
    assert.true(service.isActive, "active when both are on");

    EmbedMode.enabled = false;
    service = buildService(this.owner);
    assert.false(service.isActive, "inactive when embed mode is off");

    EmbedMode.enabled = true;
    this.siteSettings.embed_full_app_signin_flow = false;
    service = buildService(this.owner);
    assert.false(service.isActive, "inactive when site setting is off");
  });

  test("requestAccess is a no-op when inactive", async function (assert) {
    EmbedMode.enabled = false;
    const service = buildService(this.owner);

    const result = await service.requestAccess();

    assert.false(result, "returns false");
    assert.true(this.modalShow.notCalled, "no modal shown");
  });

  test("storage access already granted goes straight to sign-in", async function (assert) {
    sinon.stub(document, "hasStorageAccess").resolves(true);

    const service = buildService(this.owner);
    await service.requestAccess({ intent: "login" });

    assert.strictEqual(
      this.modalShow.firstCall.args[0],
      EmbedAuthFlowModal,
      "uses our custom modal component (native buttons preserve user activation)"
    );
    assert.strictEqual(
      modalKind(this.modalShow),
      "signin",
      "skips the storage-access prompt"
    );
  });

  test("partitioned cookies prompt for Storage Access first", async function (assert) {
    sinon.stub(document, "hasStorageAccess").resolves(false);

    const service = buildService(this.owner);
    await service.requestAccess({ intent: "login" });

    assert.strictEqual(
      modalKind(this.modalShow),
      "storage-access",
      "partitioned cookie jar needs to be bridged before sign-in"
    );
  });

  test("no Storage Access API falls back to legacy login tab", async function (assert) {
    const service = buildService(this.owner);
    sinon.stub(service, "_supportsStorageAccess").get(() => false);

    await service.requestAccess({ intent: "login" });

    assert.true(this.modalShow.notCalled, "no modal shown");
    assert.true(this.windowOpen.calledOnce, "legacy login tab opened");
    const url = this.windowOpen.firstCall.args[0];
    assert.true(url.includes("/login"), "uses /login path");
    assert.false(
      url.includes("embed_signin_callback"),
      "no callback param — would be useless without storage access"
    );
  });

  test("storage access denial does not chain to a sign-in popup", async function (assert) {
    sinon.stub(document, "hasStorageAccess").resolves(false);
    sinon.stub(document, "requestStorageAccess").rejects(new Error("denied"));

    const service = buildService(this.owner);
    await service.requestAccess({ intent: "login" });

    modalOnConfirm(this.modalShow)();

    await new Promise((resolve) => setTimeout(resolve, 0));

    assert.strictEqual(
      this.modalShow.callCount,
      1,
      "no second modal after denial — user retries on next click"
    );
    assert.strictEqual(
      sessionStorage.getItem(SESSION_KEY),
      null,
      "no post-reload state was persisted"
    );
  });

  test("opening sign-in popup uses /signup for signup intent", async function (assert) {
    sinon.stub(document, "hasStorageAccess").resolves(true);

    const service = buildService(this.owner);
    await service.requestAccess({ intent: "signup" });

    modalOnConfirm(this.modalShow)();

    assert.true(this.windowOpen.calledOnce, "window.open invoked");
    const url = this.windowOpen.firstCall.args[0];
    assert.true(url.includes("/signup"), "uses signup path");
    assert.true(
      url.includes("embed_signin_callback=1"),
      "appends callback flag"
    );
  });

  test("post-reload state with session shows nothing", function (assert) {
    logIn(this.owner);
    sessionStorage.setItem(SESSION_KEY, "post-storage-access");

    buildService(this.owner);

    assert.true(this.modalShow.notCalled, "no prompt for logged-in user");
    assert.strictEqual(
      sessionStorage.getItem(SESSION_KEY),
      null,
      "flag is cleared"
    );
  });

  test("post-reload state without session prompts for sign-in", function (assert) {
    sessionStorage.setItem(SESSION_KEY, "post-storage-access");

    buildService(this.owner);

    assert.strictEqual(modalKind(this.modalShow), "signin");
    assert.strictEqual(
      sessionStorage.getItem(SESSION_KEY),
      null,
      "flag is cleared"
    );
  });

  test("post-reload preserves signup intent across reload", function (assert) {
    sessionStorage.setItem(SESSION_KEY, "post-storage-access");
    sessionStorage.setItem(SESSION_KEY_INTENT, "signup");

    buildService(this.owner);

    assert.strictEqual(modalKind(this.modalShow), "signin");
    modalOnConfirm(this.modalShow)();

    assert.true(this.windowOpen.calledOnce, "popup opened");
    assert.true(
      this.windowOpen.firstCall.args[0].includes("/signup"),
      "uses /signup path, preserving original intent"
    );
    assert.strictEqual(
      sessionStorage.getItem(SESSION_KEY_INTENT),
      null,
      "intent flag is cleared"
    );
  });

  test("post-reload handler is skipped when inactive", function (assert) {
    sessionStorage.setItem(SESSION_KEY, "post-storage-access");
    EmbedMode.enabled = false;

    buildService(this.owner);

    assert.true(this.modalShow.notCalled, "no prompt when inactive");
    assert.strictEqual(
      sessionStorage.getItem(SESSION_KEY),
      "post-storage-access",
      "flag is not cleared so the active session can act on it later"
    );
  });
});
