import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import UploadRuntime from "discourse/components/upload-runtime";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function deferred() {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

module("Integration | Component | UploadRuntime", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const runtime = (this.runtime = {
      loaded: false,
      load: sinon.stub(),
      reload: sinon.spy(),
    });
    this.owner.register(
      "service:upload-runtime",
      class extends Service {
        get loaded() {
          return runtime.loaded;
        }

        load() {
          return runtime.load();
        }

        reload() {
          runtime.reload();
        }
      }
    );
    this.alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("mounts children only after loading completes", async function (assert) {
    const loading = deferred();
    this.runtime.load.returns(loading.promise);
    let mounts = 0;
    class Uploader extends Component {
      constructor() {
        super(...arguments);
        mounts++;
      }

      <template><input class="upload-input" type="file" /></template>
    }

    await render(
      <template>
        <UploadRuntime><Uploader /></UploadRuntime>
      </template>
    );
    assert.strictEqual(mounts, 0, "the uploader lifecycle has not started");
    assert.dom(".upload-input").doesNotExist("no input mounts during loading");

    loading.resolve();
    await settled();
    assert.strictEqual(mounts, 1, "the uploader mounts after loading");
    assert.dom(".upload-input").exists("the input is available");
  });

  test("renders immediately when the runtime is already loaded", async function (assert) {
    this.runtime.loaded = true;
    await render(
      <template>
        <UploadRuntime><input class="upload-input" /></UploadRuntime>
      </template>
    );
    assert.dom(".upload-input").exists("cached content renders immediately");
    assert.false(this.runtime.load.called, "no further load is requested");
  });

  test("offers a page refresh after a load failure", async function (assert) {
    this.runtime.load.rejects({ responseJSON: { errors: ["failed"] } });
    await render(
      <template>
        <UploadRuntime><input class="upload-input" /></UploadRuntime>
      </template>
    );
    assert.dom(".upload-input").doesNotExist("failed content does not mount");
    assert.true(this.alert.calledOnce, "the load failure is reported");
    await click("button");
    assert.true(
      this.runtime.reload.calledOnce,
      "recovery requests a page refresh"
    );
    assert.true(
      this.runtime.load.calledOnce,
      "a cached failed import is not retried"
    );
  });

  test("can wait without a spinner", async function (assert) {
    const loading = deferred();
    this.runtime.load.returns(loading.promise);
    await render(
      <template>
        <UploadRuntime @showSpinner={{false}}><input
            class="upload-input"
          /></UploadRuntime>
      </template>
    );
    assert.dom(".spinner").doesNotExist("nothing renders while loading");

    loading.resolve();
    await settled();
    assert.dom(".upload-input").exists("the content mounts after loading");
  });

  test("does not mount children after destruction during loading", async function (assert) {
    const loading = deferred();
    const visible = tracked(true);
    this.runtime.load.returns(loading.promise);
    await render(
      <template>
        {{#if visible.value}}<UploadRuntime><input
              class="upload-input"
            /></UploadRuntime>{{/if}}
      </template>
    );
    visible.value = false;
    await settled();
    loading.resolve();
    await settled();
    assert
      .dom(".upload-input")
      .doesNotExist("destroyed content stays unmounted");
    assert.false(this.alert.called, "no error is reported after destruction");
  });

  test("ignores a load failure after destruction", async function (assert) {
    const loading = deferred();
    const visible = tracked(true);
    this.runtime.load.returns(loading.promise);
    await render(
      <template>
        {{#if visible.value}}<UploadRuntime><input
              class="upload-input"
            /></UploadRuntime>{{/if}}
      </template>
    );
    visible.value = false;
    await settled();
    loading.reject({ responseJSON: { errors: ["failed"] } });
    await settled();
    assert.false(this.alert.called, "a stale failure does not open a dialog");
  });
});
