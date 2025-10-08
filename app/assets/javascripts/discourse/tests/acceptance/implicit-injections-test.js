import { getOwner, setOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import { test } from "qunit";
import RestModel from "discourse/models/rest";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Implicit injections shims", function () {
  test("it provides legacy injections on common models", function (assert) {
    const serviceInstance = Service.create();
    setOwner(serviceInstance, getOwner(this));

    assert.strictEqual(
      serviceInstance.session,
      getOwner(this).lookup("service:session")
    );
  });

  test("it allows overlaying explicit injections", function (assert) {
    class MyService extends Service {
      // eslint-disable-next-line discourse/no-unused-services
      @service session;
    }
    const serviceInstance = MyService.create();
    setOwner(serviceInstance, getOwner(this));

    assert.strictEqual(
      serviceInstance.session,
      getOwner(this).lookup("service:session")
    );
  });

  test("it allows overriding values by assignment", function (assert) {
    const serviceInstance = Service.create({ session: "an override" });
    setOwner(serviceInstance, getOwner(this));

    assert.strictEqual(serviceInstance.session, "an override");
  });

  test("passes through assigned values when creating from another object", async function (assert) {
    const initialModel = RestModel.create({
      appEvents: "overridden app events",
    });

    assert.strictEqual(
      initialModel.appEvents,
      "overridden app events",
      "overridden app events are set correctly"
    );

    const newModel = RestModel.create(initialModel);
    assert.strictEqual(
      newModel.appEvents,
      "overridden app events",
      "overridden app events are passed though when creating from another objects"
    );
  });
});
