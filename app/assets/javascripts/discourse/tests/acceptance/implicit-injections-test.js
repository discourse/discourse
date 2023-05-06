import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import Service, { inject as service } from "@ember/service";
import { getOwner, setOwner } from "@ember/application";

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
});
