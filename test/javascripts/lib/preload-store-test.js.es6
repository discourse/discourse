import PreloadStore from "preload-store";
import { asyncTestDiscourse } from "helpers/qunit-helpers";
import { Promise } from "rsvp";

QUnit.module("preload-store", {
  beforeEach() {
    PreloadStore.store("bane", "evil");
  }
});

QUnit.test("get", assert => {
  assert.blank(PreloadStore.get("joker"), "returns blank for a missing key");
  assert.equal(
    PreloadStore.get("bane"),
    "evil",
    "returns the value for that key"
  );
});

QUnit.test("remove", assert => {
  PreloadStore.remove("bane");
  assert.blank(PreloadStore.get("bane"), "removes the value if the key exists");
});

asyncTestDiscourse(
  "getAndRemove returns a promise that resolves to null",
  function(assert) {
    assert.expect(1);

    const done = assert.async();
    PreloadStore.getAndRemove("joker").then(function(result) {
      assert.blank(result);
      done();
    });
  }
);

asyncTestDiscourse(
  "getAndRemove returns a promise that resolves to the result of the finder",
  function(assert) {
    assert.expect(1);

    const done = assert.async();
    const finder = function() {
      return "batdance";
    };
    PreloadStore.getAndRemove("joker", finder).then(function(result) {
      assert.equal(result, "batdance");
      done();
    });
  }
);

asyncTestDiscourse(
  "getAndRemove returns a promise that resolves to the result of the finder's promise",
  function(assert) {
    assert.expect(1);

    const finder = function() {
      return new Promise(function(resolve) {
        resolve("hahahah");
      });
    };

    const done = assert.async();
    PreloadStore.getAndRemove("joker", finder).then(function(result) {
      assert.equal(result, "hahahah");
      done();
    });
  }
);

asyncTestDiscourse(
  "returns a promise that rejects with the result of the finder's rejected promise",
  function(assert) {
    assert.expect(1);

    const finder = function() {
      return new Promise(function(resolve, reject) {
        reject("error");
      });
    };

    const done = assert.async();
    PreloadStore.getAndRemove("joker", finder).then(null, function(result) {
      assert.equal(result, "error");
      done();
    });
  }
);

asyncTestDiscourse("returns a promise that resolves to 'evil'", function(
  assert
) {
  assert.expect(1);

  const done = assert.async();
  PreloadStore.getAndRemove("bane").then(function(result) {
    assert.equal(result, "evil");
    done();
  });
});
