import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import EmbedAuthFlowModal from "discourse/components/modal/embed-auth-flow";
import EmbedMode from "discourse/lib/embed-mode";

function buildService(owner) {
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

    this.modalShow = sinon.stub(this.modalService, "show");
    this.windowOpen = sinon
      .stub(window, "open")
      .returns({ closed: false, close: sinon.stub() });
  });

  hooks.afterEach(function () {
    EmbedMode.enabled = this.originalEmbedMode;
    sinon.restore();
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
    sinon.stub(service, "_isUserSignedIn").resolves(false);

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
  });

  test("storage access grant chains into the sign-in modal", async function (assert) {
    const hasStorageAccess = sinon.stub(document, "hasStorageAccess");
    hasStorageAccess.onFirstCall().resolves(false);
    hasStorageAccess.resolves(true);
    sinon.stub(document, "requestStorageAccess").resolves();

    const service = buildService(this.owner);
    sinon.stub(service, "_isUserSignedIn").resolves(false);

    await service.requestAccess({ intent: "signup" });

    assert.strictEqual(
      modalKind(this.modalShow),
      "storage-access",
      "starts with the storage-access prompt"
    );

    modalOnConfirm(this.modalShow)();

    await new Promise((resolve) => setTimeout(resolve, 0));

    assert.strictEqual(
      this.modalShow.callCount,
      2,
      "shows the sign-in modal once access is granted"
    );
    assert.strictEqual(
      modalKind(this.modalShow, 1),
      "signin",
      "chains directly into sign-in without reloading"
    );
  });

  test("already-signed-in user gets a reload instead of the sign-in popup", async function (assert) {
    sinon.stub(document, "hasStorageAccess").resolves(true);

    const service = buildService(this.owner);
    sinon.stub(service, "_isUserSignedIn").resolves(true);
    const reload = sinon.stub(service, "_reload");

    await service.requestAccess({ intent: "login" });

    assert.true(reload.calledOnce, "reload invoked to pick up the session");
    assert.true(
      this.modalShow.notCalled,
      "sign-in modal is skipped — no popup needed"
    );
  });

  test("opening sign-in popup uses /signup for signup intent", async function (assert) {
    sinon.stub(document, "hasStorageAccess").resolves(true);

    const service = buildService(this.owner);
    sinon.stub(service, "_isUserSignedIn").resolves(false);

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
});
