import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { getOwnerWithFallback, setDefaultOwner } from "discourse/lib/get-owner";
import voiceLog from "discourse/plugins/voice/discourse/lib/voice/logger";

module("Voice | Unit | Lib | logger", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalOwner = getOwnerWithFallback();
    setDefaultOwner(this.owner);
    this.info = sinon.stub(console, "info");
    this.warn = sinon.stub(console, "warn");
    this.siteSettings = this.owner.lookup("service:site-settings");
  });

  hooks.afterEach(function () {
    setDefaultOwner(this.originalOwner);
    this.info.restore();
    this.warn.restore();
  });

  test("logging is disabled by default", function (assert) {
    assert.false(
      this.siteSettings.voice_verbose_logging,
      "verbose logging defaults to off"
    );

    voiceLog.info("[voice] local stream obtained");
    voiceLog.warn("[voice] failed to obtain local stream");

    assert.false(this.info.called, "info is silent");
    assert.false(this.warn.called, "warnings are silent");
  });

  test("logging follows changes to the setting", function (assert) {
    this.siteSettings.voice_verbose_logging = true;
    voiceLog.info("[voice] local stream obtained");
    voiceLog.warn("[voice] failed to obtain local stream");
    this.siteSettings.voice_verbose_logging = false;
    voiceLog.info("[voice] local stream obtained");
    voiceLog.warn("[voice] failed to obtain local stream");

    assert.true(
      this.info.calledOnceWithExactly("[voice] local stream obtained"),
      "info logs only when enabled"
    );
    assert.true(
      this.warn.calledOnceWithExactly("[voice] failed to obtain local stream"),
      "warnings log only when enabled"
    );
  });

  test("raw error and payload arguments are excluded", function (assert) {
    this.siteSettings.voice_verbose_logging = true;
    const error = new Error("secret credential and transcript");
    const payload = { candidate: "private IP address", token: "secret token" };

    voiceLog.info("[voice] received signal", payload);
    voiceLog.warn("[voice] failed to obtain local stream", error, payload);

    assert.deepEqual(
      this.info.firstCall.args,
      ["[voice] received signal"],
      "payloads are omitted"
    );
    assert.deepEqual(
      this.warn.firstCall.args,
      ["[voice] failed to obtain local stream"],
      "errors are omitted"
    );
  });
});
