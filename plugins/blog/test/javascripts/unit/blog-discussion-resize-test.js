import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import EmbedMode from "discourse/lib/embed-mode";
import initializer from "discourse/plugins/blog/discourse/initializers/blog-discussion-resize";

module("Unit | Initializer | blog-discussion-resize", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.sandbox = sinon.createSandbox();
    this.embedEnabled = EmbedMode.enabled;
    this.hadClass = document.documentElement.classList.contains(
      "discourse-blog-discussion"
    );
    EmbedMode.enabled = true;
    document.documentElement.classList.add("discourse-blog-discussion");
    const settings = this.owner.lookup("service:site-settings");
    settings.blog_enabled = true;
    settings.blog_url = "https://blog.example.com";
  });

  hooks.afterEach(function () {
    initializer.teardown();
    this.sandbox.restore();
    EmbedMode.enabled = this.embedEnabled;
    document.documentElement.classList.toggle(
      "discourse-blog-discussion",
      this.hadClass
    );
  });

  test("leaves the embed unmanaged when the blog URL is unusable", function (assert) {
    const settings = this.owner.lookup("service:site-settings");
    settings.blog_url = "not a url";
    const observe = this.sandbox.stub();
    this.sandbox.stub(window, "ResizeObserver").callsFake(() => ({
      observe,
      disconnect() {},
    }));

    initializer.initialize(this.owner);

    assert.true(
      observe.notCalled,
      "no observer without a usable parent origin"
    );
  });

  test("continues sizing beyond the initial notifications and cleans up", function (assert) {
    let resize;
    const disconnect = this.sandbox.spy();
    const element = {
      scrollHeight: 1800,
      getBoundingClientRect: () => ({ height: 1800.3 }),
    };
    this.sandbox
      .stub(document, "getElementById")
      .withArgs("main")
      .returns(element);
    this.sandbox.stub(window, "ResizeObserver").callsFake(function (callback) {
      resize = callback;
      return {
        observe: (target, options) => {
          assert.deepEqual(
            options,
            { box: "border-box" },
            "composer padding and border changes trigger resizing"
          );
        },
        disconnect,
      };
    });
    this.sandbox.stub(window, "requestAnimationFrame").callsFake((callback) => {
      callback();
      return 1;
    });
    this.sandbox.stub(window, "cancelAnimationFrame");
    const postMessage = this.sandbox.stub(window.parent, "postMessage");

    initializer.initialize(this.owner);
    for (let index = 0; index < 12; index++) {
      element.scrollHeight += 20;
      resize();
    }
    resize();

    assert.strictEqual(
      postMessage.callCount,
      12,
      "sizing remains active and unchanged heights are skipped"
    );
    assert.deepEqual(
      postMessage.lastCall.args,
      [
        { type: "discourse-blog-resize", height: 2040 },
        "https://blog.example.com",
      ],
      "height is sent only to the configured parent origin"
    );
    initializer.teardown();
    assert.true(disconnect.calledOnce, "the observer disconnects on teardown");
  });
});
