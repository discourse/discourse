import { module, test } from "qunit";
import { MultiCache } from "discourse/lib/multi-cache";

module("Unit | Utils | multi-cache", function (hooks) {
  let requests, cache;

  hooks.beforeEach(() => {
    requests = [];

    cache = new MultiCache(
      (ids) =>
        new Promise((resolve, reject) => {
          requests.push({ ids, resolve, reject });
        })
    );
  });

  test("cache miss then hit", async (assert) => {
    const missResponse = cache.fetch([10]);

    assert.strictEqual(requests.length, 1, "one triggered request");

    const [request] = requests;
    requests.clear();

    assert.deepEqual(request.ids, [10], "request has correct ids");

    request.resolve(new Map([[10, "foo"]]));

    const missResult = await missResponse;

    assert.strictEqual(missResult.constructor, Map, "response is a Map");
    assert.strictEqual(missResult.size, 1, "response has one entry");
    assert.strictEqual(missResult.get(10), "foo", "response entry is correct");

    const hitResponse = cache.fetch([10]);
    assert.strictEqual(requests.length, 0);

    const hitResult = await hitResponse;

    assert.strictEqual(hitResult.constructor, Map, "second response is a Map");
    assert.strictEqual(hitResult.size, 1, "second response has one entry");
    assert.strictEqual(
      hitResult.get(10),
      "foo",
      "second response entry is correct"
    );
  });

  test("failure then refetch", async (assert) => {
    const response1 = cache.fetch([10]);

    assert.strictEqual(requests.length, 1);
    const [request1] = requests;
    requests.clear();
    assert.deepEqual(request1.ids, [10]);

    request1.reject();

    assert.rejects(response1);

    try {
      await response1;
    } catch {}

    const response2 = cache.fetch([10]);
    assert.strictEqual(requests.length, 1);
    const [request2] = requests;
    assert.deepEqual(request2.ids, [10]);

    request2.resolve(new Map([[10, "foo"]]));

    const result = await response2;

    assert.strictEqual(result.constructor, Map);
    assert.strictEqual(result.size, 1);
    assert.strictEqual(result.get(10), "foo");
  });

  test("multiple requests before resolution", async (assert) => {
    const response1 = cache.fetch([10]);
    const response2 = cache.fetch([10]);

    assert.strictEqual(requests.length, 1);
    const [request] = requests;
    assert.deepEqual(request.ids, [10]);

    request.resolve(new Map([[10, "foo"]]));

    for (const response of [response1, response2]) {
      const result = await response;

      assert.strictEqual(result.constructor, Map);
      assert.strictEqual(result.size, 1);
      assert.strictEqual(result.get(10), "foo");
    }
  });

  test("overlapping requests", async (assert) => {
    const response1 = cache.fetch([10, 20]);
    const response2 = cache.fetch([10, 30]);

    assert.strictEqual(requests.length, 2);
    const [request1, request2] = requests;

    assert.deepEqual(request1.ids, [10, 20]);
    assert.deepEqual(request2.ids, [30]);

    request1.resolve(
      new Map([
        [10, "foo"],
        [20, "bar"],
      ])
    );
    request2.resolve(new Map([[30, "baz"]]));

    const result1 = await response1;

    assert.strictEqual(result1.constructor, Map);
    assert.strictEqual(result1.size, 2);
    assert.strictEqual(result1.get(10), "foo");
    assert.strictEqual(result1.get(20), "bar");

    const result2 = await response2;

    assert.strictEqual(result2.constructor, Map);
    assert.strictEqual(result2.size, 2);
    assert.strictEqual(result2.get(10), "foo");
    assert.strictEqual(result2.get(30), "baz");
  });
});
