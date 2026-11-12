import EmberObject, { computed, get } from "@ember/object";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Badge from "discourse/models/badge";

module("Unit | Data | warp-rest-model", function (hooks) {
  setupTest(hooks);

  test("schema forwarders invalidate classic computed consumers on cache updates and assignment", async function (assert) {
    const store = this.owner.lookup("service:warp-store");
    const badge = Badge.createFromJson({ badge: { id: 123, name: "Before" } });
    class Consumer extends EmberObject {
      @computed("badge.name")
      get label() {
        return this.badge.name;
      }
    }
    const consumer = Consumer.create({ badge });

    assert.strictEqual(
      get(consumer, "label"),
      "Before",
      "the computed value is initially cached"
    );

    store.push({
      data: { type: "badge", id: "123", attributes: { name: "From server" } },
    });
    await settled();

    assert.strictEqual(
      get(consumer, "label"),
      "From server",
      "a cache update invalidates the wrapper's dependent key"
    );

    badge.name = "From assignment";
    await settled();

    assert.strictEqual(
      get(consumer, "label"),
      "From assignment",
      "assignment also invalidates the classic computed value"
    );
    assert.strictEqual(
      get(badge, "name"),
      "From assignment",
      "the forwarder remains writable"
    );
    assert.strictEqual(
      store.peekRecord({ type: "badge", id: "123" }).name,
      "From assignment",
      "assignment updates the cached record"
    );
    consumer.destroy();
  });
});
