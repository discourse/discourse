import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";

module("Unit | Utility | text-area-manipulation", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("applySurround - add", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "Hello World";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");

    assert.strictEqual(textarea.value, "**Hello World**");
  });

  test("applySurround - remove", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "**Hello World**";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");

    assert.strictEqual(textarea.value, "Hello World");
  });

  test("applySurround - one side", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "Hello World**";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");
    assert.strictEqual(textarea.value, "**Hello World****");

    textarea.value = "**Hello World";
    textarea.select();
    manipulation.applySurroundSelection("**", "**", "example");
    assert.strictEqual(textarea.value, "****Hello World**");
  });

  test("emojiSelected - replaces ASCII partial term", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = ":trau";
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    manipulation.emojiSelected("disappointed");

    assert.strictEqual(textarea.value, ":disappointed:");
  });

  test("emojiSelected - replaces partial term containing Unicode letters", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = ":glücklich";
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    manipulation.emojiSelected("smile");

    assert.strictEqual(textarea.value, ":smile:");
  });

  test("emojiSelected - appends emoji when no partial term is present", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    const manipulation = new TextareaTextManipulation(getOwner(this), {
      textarea,
    });

    textarea.value = "hello";
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    manipulation.emojiSelected("smile");

    assert.strictEqual(textarea.value, "hello :smile:");
  });

  test("falls back to plain text when rich HTML converts to empty markdown", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;

    let prevented = false;
    await manipulation.paste({
      target: textarea,
      preventDefault() {
        prevented = true;
      },
      clipboardData: {
        files: [],
        types: ["text/plain", "text/html"],
        getData(type) {
          if (type === "text/plain") {
            return "plain fallback";
          }
          if (type === "text/html") {
            return "<span></span>";
          }
        },
      },
    });

    assert.true(prevented, "native paste is prevented for handled rich paste");
    assert.strictEqual(textarea.value, "plain fallback");
  });

  test("reads missing HTML from the Android clipboard", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;
    sinon.stub(manipulation.capabilities, "isAndroid").value(true);
    sinon.stub(manipulation.capabilities, "isChrome").value(true);
    const getType = sinon
      .stub()
      .withArgs("text/html")
      .resolves(
        new Blob(["<strong>formatted</strong>"], { type: "text/html" })
      );
    sinon.stub(navigator.clipboard, "read").resolves([
      {
        types: ["text/plain", "text/html"],
        getType,
      },
    ]);

    let prevented = false;
    await manipulation.paste({
      target: textarea,
      preventDefault() {
        prevented = true;
      },
      clipboardData: {
        files: [],
        types: ["text/plain"],
        getData(type) {
          return type === "text/plain" ? "formatted" : "";
        },
      },
    });

    assert.true(prevented, "native paste is prevented while reading HTML");
    assert.strictEqual(textarea.value, "**formatted**");
    assert.true(
      getType.calledOnce,
      "the HTML clipboard representation is read"
    );
  });

  test("reads Android clipboard HTML when the paste event advertises an empty HTML payload", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;
    sinon.stub(manipulation.capabilities, "isAndroid").value(true);
    sinon.stub(manipulation.capabilities, "isChrome").value(true);
    sinon.stub(navigator.clipboard, "read").resolves([
      {
        types: ["text/html"],
        getType: sinon
          .stub()
          .resolves(new Blob(["<em>formatted</em>"], { type: "text/html" })),
      },
    ]);

    await manipulation.paste({
      target: textarea,
      preventDefault() {},
      clipboardData: {
        files: [],
        types: ["text/plain", "text/html"],
        getData(type) {
          return type === "text/plain" ? "formatted" : "";
        },
      },
    });

    assert.strictEqual(textarea.value, "*formatted*");
  });

  test("falls back to plain text when the Android clipboard read fails", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;
    sinon.stub(manipulation.capabilities, "isAndroid").value(true);
    sinon.stub(manipulation.capabilities, "isChrome").value(true);
    sinon.stub(navigator.clipboard, "read").rejects(new Error("not allowed"));

    let prevented = false;
    await manipulation.paste({
      target: textarea,
      preventDefault() {
        prevented = true;
      },
      clipboardData: {
        files: [],
        types: ["text/plain"],
        getData(type) {
          return type === "text/plain" ? "plain fallback" : "";
        },
      },
    });

    assert.true(prevented, "native paste is prevented while reading HTML");
    assert.strictEqual(textarea.value, "plain fallback");
  });

  test("does not read from the Async Clipboard API outside Android", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;
    sinon.stub(manipulation.capabilities, "isAndroid").value(false);
    sinon.stub(manipulation.capabilities, "isChrome").value(true);
    const read = sinon.stub(navigator.clipboard, "read");

    let prevented = false;
    await manipulation.paste({
      target: textarea,
      preventDefault() {
        prevented = true;
      },
      clipboardData: {
        files: [],
        types: ["text/plain"],
        getData(type) {
          return type === "text/plain" ? "plain text" : "";
        },
      },
    });

    assert.false(read.called, "the clipboard is not read");
    assert.false(prevented, "native plain-text paste is unchanged");
  });

  test("does not read from the Async Clipboard API on non-Chromium Android browsers", async function (assert) {
    const textarea = document.createElement("textarea");
    document.body.appendChild(textarea);
    textarea.setSelectionRange(0, 0);

    const manipulation = new TextareaTextManipulation(getOwner(this), {
      eventPrefix: null,
      textarea,
    });
    manipulation.siteSettings.enable_rich_text_paste = true;
    sinon.stub(manipulation.capabilities, "isAndroid").value(true);
    sinon.stub(manipulation.capabilities, "isChrome").value(false);
    const read = sinon.stub(navigator.clipboard, "read");

    let prevented = false;
    await manipulation.paste({
      target: textarea,
      preventDefault() {
        prevented = true;
      },
      clipboardData: {
        files: [],
        types: ["text/plain"],
        getData(type) {
          return type === "text/plain" ? "plain text" : "";
        },
      },
    });

    assert.false(read.called, "the clipboard is not read");
    assert.false(prevented, "native plain-text paste is unchanged");
  });
});
