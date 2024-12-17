import { tracked } from "@glimmer/tracking";
import { clearRender, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ComposerPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/composer-presence-display";

module("Integration | Component | composer-presence-display", function (hooks) {
  setupRenderingTest(hooks);

  test("does not call `leave` excessively", async function (assert) {
    const manager = this.owner.lookup("service:composer-presence-manager");
    const spy = sinon.spy(manager, "leave");
    pretender.post("/presence/update", () => response({}));

    const store = this.owner.lookup("service:store");
    const model = new (class {
      @tracked reply = "foo";
      post = store.createRecord("post", { id: 123, raw: "foo" });
      editingPost = true;
    })();

    await render(<template>
      <ComposerPresenceDisplay @model={{model}} />
    </template>);

    assert.strictEqual(spy.callCount, 0);

    model.reply = "foo bar";
    await settled();

    model.reply = "foo baz";
    await settled();

    assert.strictEqual(spy.callCount, 0);

    await clearRender();
    assert.strictEqual(spy.callCount, 1);
  });
});
