import { module, test } from "qunit";
import TopicFromParams, {
  nestedQueryString,
} from "discourse/routes/topic/from-params";

module("Unit | Route | topic.from-params", function () {
  test("opts out of the global route scroll manager", function (assert) {
    assert.deepEqual(TopicFromParams.prototype.buildRouteInfoMetadata(), {
      scrollOnTransition: false,
    });
  });

  test("encodes nested JSON query params", function (assert) {
    const query = nestedQueryString({
      sort: "new&track_visit=false",
      track_visit: true,
      context: "0&sort=old",
      skipped: null,
    });
    const parsed = new URLSearchParams(query);

    assert.strictEqual(parsed.get("sort"), "new&track_visit=false");
    assert.strictEqual(parsed.get("track_visit"), "true");
    assert.strictEqual(parsed.get("context"), "0&sort=old");
    assert.false(parsed.has("skipped"));
    assert.false(parsed.has("bad"), "does not allow query injection");
  });
});
