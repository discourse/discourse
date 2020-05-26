import PreloadStore from "discourse/lib/preload-store";
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

QUnit.test(
  "getAndRemove returns a promise that resolves to null",
  async assert => {
    assert.blank(await PreloadStore.getAndRemove("joker"));
  }
);

QUnit.test(
  "getAndRemove returns a promise that resolves to the result of the finder",
  async assert => {
    const finder = () => "batdance";
    const result = await PreloadStore.getAndRemove("joker", finder);

    assert.equal(result, "batdance");
  }
);

QUnit.test(
  "getAndRemove returns a promise that resolves to the result of the finder's promise",
  async assert => {
    const finder = () => Promise.resolve("hahahah");
    const result = await PreloadStore.getAndRemove("joker", finder);

    assert.equal(result, "hahahah");
  }
);

QUnit.test(
  "returns a promise that rejects with the result of the finder's rejected promise",
  async assert => {
    const finder = () => Promise.reject("error");

    await PreloadStore.getAndRemove("joker", finder).catch(result => {
      assert.equal(result, "error");
    });
  }
);

QUnit.test("returns a promise that resolves to 'evil'", async assert => {
  const result = await PreloadStore.getAndRemove("bane");
  assert.equal(result, "evil");
});
