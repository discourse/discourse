import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { module, test } from "qunit";
import classPrepend, { rollbackAllPrepends } from "discourse/lib/class-prepend";

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

  test("can modify same class twice", function (assert) {
    class Topic {
      get someGetter() {
        return "original";
      }
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          get someGetter() {
            return `${super.someGetter} modified1`;
          }
        }
    );

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          get someGetter() {
            return `${super.someGetter} modified2`;
          }
        }
    );

    assert.strictEqual(
      new Topic().someGetter,
      "original modified1 modified2",
      "it works"
    );
  });

  test("doesn't affect parent class private fields", function (assert) {
    class Topic {
      #somePrivateField = "supersecret";

      get someGetter() {
        return this.#somePrivateField;
      }
    }

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          get someGetter() {
            return `${super.someGetter} modified`;
          }
        }
    );

    assert.strictEqual(new Topic().someGetter, "supersecret modified");
  });

  test("static this is correct in static methods", function (assert) {
    class Topic {}

    classPrepend(
      Topic,
      (Superclass) =>
        class extends Superclass {
          static someStaticField = this;
          static someStaticMethod() {
            return this;
          }
        }
    );

    assert.strictEqual(
      Topic.someStaticMethod(),
      Topic,
      "`this` referrs to the original class in static methods"
    );

    // Known limitation - `this` in static field overrides is wrong
    assert.notStrictEqual(
      Topic.someStaticField,
      Topic,
      "`this` referrs to the temporary superclass in static fields"
    );
  });

  test("changes can be rolled back", function (assert) {
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
            return 2;
          }
        }
    );

    assert.strictEqual(new Topic().someFunction(), 2, "change is applied");

    rollbackAllPrepends();

    assert.strictEqual(new Topic().someFunction(), 1, "change is rolled back");
  });

  test("can override method from parent, with super support", function (assert) {
    class Parent {
      someFunction() {
        return 1;
      }
    }

    class Child extends Parent {}

    classPrepend(
      Child,
      (Superclass) =>
        class extends Superclass {
          someFunction() {
            return super.someFunction() + 1;
          }
        }
    );

    assert.strictEqual(new Child().someFunction(), 2, "it works");
  });
});
