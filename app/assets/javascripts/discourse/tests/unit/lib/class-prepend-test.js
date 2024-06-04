import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { module, test } from "qunit";
import classPrepend from "discourse/lib/class-prepend";

module("Unit | class-prepend", function () {
  test("can override function, with super support", function (assert) {
    class Topic {
      someFunction() {
        return 1;
      }
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          someFunction() {
            return super.someFunction() + 1;
          }
        }
    );

    assert.strictEqual(new Topic().someFunction(), 2, "it works");
  });

  test("can override getter, with super support", function (assert) {
    class Topic {
      get someGetter() {
        return 1;
      }
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          get someGetter() {
            return super.someGetter + 1;
          }
        }
    );

    assert.strictEqual(new Topic().someGetter, 2, "it works");
  });

  test("can override `@action` function, with super support", function (assert) {
    class Topic {
      @action
      someFunction() {
        return 1;
      }
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          @action
          someFunction() {
            return super.someFunction() + 1;
          }
        }
    );

    assert.strictEqual(new Topic().someFunction(), 2, "it works");
  });

  test("can override static function, with super support", function (assert) {
    class Topic {
      static someFunction() {
        return 1;
      }
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          static someFunction() {
            return super.someFunction() + 1;
          }
        }
    );

    assert.strictEqual(Topic.someFunction(), 2, "it works");
  });

  test("can override static field", function (assert) {
    class Topic {
      static someStaticField = 1;
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          static someStaticField = 2;
        }
    );

    assert.strictEqual(Topic.someStaticField, 2, "it works");
  });

  test("cannot override instance field", function (assert) {
    class Topic {
      someField = 1;
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          someField = 2;
        }
    );

    assert.strictEqual(
      new Topic().someField,
      1,
      "it doesn't override the field"
    );
  });

  test("can override @tracked fields", function (assert) {
    class Topic {
      @tracked someField = 1;
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          @tracked someField = 2;
        }
    );

    assert.strictEqual(new Topic().someField, 2, "it works");
  });

  test("has correct inheritance order when overriding method in parent class", function (assert) {
    class Parent {
      someFunction() {
        return "parent";
      }
    }

    class Child extends Parent {
      someFunction() {
        return `${super.someFunction()} child`;
      }
    }

    classPrepend(
      Parent,
      (Superclass) =>
        class extends Superclass {
          someFunction() {
            return `${super.someFunction()} prepended`;
          }
        }
    );

    assert.strictEqual(
      new Child().someFunction(),
      "parent prepended child",
      "it works"
    );
  });
});
