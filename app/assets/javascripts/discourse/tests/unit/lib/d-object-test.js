import { getOwner, setOwner } from "@ember/application";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import DObject, { attr, emberObjectCompat } from "discourse/lib/d-object";

class TestPerson extends DObject {
  @attr id;
  @attr name;
  @attr age;
  @attr({ readOnly: true }) immutableProp;
}

class TestChild extends TestPerson {
  @attr parent;
}

@emberObjectCompat
class CompatTestPerson extends TestPerson {}

module("Unit | DObject", function (hooks) {
  setupTest(hooks);

  test("it works", function (assert) {
    const person = new TestPerson(getOwner(this), {
      id: 1,
      name: "bob",
      age: 20,
      unknownProp: "foo",
    });

    assert.strictEqual(person.id, 1);
    assert.strictEqual(person.name, "bob");
    assert.strictEqual(person.age, 20);
    assert.strictEqual(person.unknownProp, undefined);
  });

  test("attrs in child class", function (assert) {
    const child = new TestChild(getOwner(this), {
      id: 1,
      name: "bob",
      age: 20,
      parent: "bob",
    });

    assert.strictEqual(child.id, 1);
    assert.strictEqual(child.name, "bob");
    assert.strictEqual(child.age, 20);
    assert.strictEqual(child.parent, "bob");
  });

  test("it can optionally have EmberObject function compatibility", function (assert) {
    const props = {
      id: 1,
      name: "bob",
      age: 20,
      unknownProp: "foo",
    };
    setOwner(props, getOwner(this));
    const person = CompatTestPerson.create(props);

    assert.strictEqual(person.get("id"), 1);
    assert.strictEqual(person.get("name"), "bob");
    assert.strictEqual(person.get("age"), 20);

    person.set("name", "alice");
    assert.strictEqual(person.name, "alice");

    person.setProperties({ name: "bob", age: 30 });
    assert.strictEqual(person.name, "bob");
    assert.strictEqual(person.age, 30);

    assert.deepEqual(person.getProperties("name", "age"), {
      name: "bob",
      age: 30,
    });
  });

  test("it allows readonly attributes", function (assert) {
    const person = new TestPerson(getOwner(this), {
      immutableProp: "foo",
    });

    assert.strictEqual(person.immutableProp, "foo");
    assert.throws(() => {
      person.immutableProp = "bar";
    }, /Cannot assign to read only property/);
  });
});
