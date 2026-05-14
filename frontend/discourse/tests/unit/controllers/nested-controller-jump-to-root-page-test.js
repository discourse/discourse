import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function fakeTopic() {
  return {
    id: 42,
    slug: "demo-topic",
    suggested_topics: null,
    related_topics: null,
  };
}

function makeRootNode(postNumber, id = postNumber * 100) {
  return { post: { id, post_number: postNumber }, children: [] };
}

function registerStubElement(controller, postNumber, top) {
  // Stub a DOM element that .getBoundingClientRect returns deterministically,
  // so the scroll math doesn't depend on real layout in the test runner.
  const el = {
    isConnected: true,
    getBoundingClientRect: () => ({ top, left: 0, right: 0, bottom: top + 10 }),
  };
  controller.nestedRootElements.register(postNumber, el);
  return el;
}

module("Unit | Controller | nested - jumpToRootPage", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.controller = getOwner(this).lookup("controller:nested");
    this.controller.nestedRootElements.clear();
    this.scrollSpy = sinon.stub(window, "scrollTo");
  });

  hooks.afterEach(function () {
    this.scrollSpy.restore();
  });

  test("in-window jump with target post just scrolls to it", async function (assert) {
    this.controller.setProperties({
      topic: fakeTopic(),
      rootNodes: [makeRootNode(5), makeRootNode(7), makeRootNode(9)],
      firstLoadedPage: 0,
      page: 0,
      rootSummary: { page_size: 3, total: 3 },
      sort: "top",
    });
    registerStubElement(this.controller, 9, 1234);

    await this.controller.jumpToRootPage(0, 9);

    assert.true(
      this.scrollSpy.called,
      "scrolls without an ajax fetch when target is in the loaded window"
    );
    assert.strictEqual(
      this.controller.rootNodes.length,
      3,
      "rootNodes unchanged"
    );
  });

  test("out-of-window jump replaces rootNodes with the target page", async function (assert) {
    pretender.get("/n/demo-topic/42.json", (request) => {
      assert.strictEqual(request.queryParams.page, "3", "fetches target page");
      return response({
        roots: [
          { id: 100, post_number: 50 },
          { id: 101, post_number: 51 },
        ],
        page: 3,
        has_more_roots: true,
      });
    });

    this.controller.setProperties({
      topic: fakeTopic(),
      rootNodes: [makeRootNode(5)],
      firstLoadedPage: 0,
      page: 0,
      rootSummary: { page_size: 2, total: 100 },
      sort: "top",
    });
    // Pre-register so waitForElement resolves immediately.
    registerStubElement(this.controller, 50, 800);

    await this.controller.jumpToRootPage(3, 50);
    await settled();

    assert.deepEqual(
      this.controller.rootNodes.map((n) => n.post.post_number),
      [50, 51],
      "replaces (not appends) rootNodes with the target page"
    );
    assert.strictEqual(this.controller.firstLoadedPage, 3);
    assert.strictEqual(this.controller.page, 3, "collapses window to one page");
    assert.true(this.controller.hasMoreRoots);
  });

  test("uses first node post_number when no target is given", async function (assert) {
    pretender.get("/n/demo-topic/42.json", () =>
      response({
        roots: [
          { id: 200, post_number: 80 },
          { id: 201, post_number: 81 },
        ],
        page: 5,
        has_more_roots: false,
      })
    );

    this.controller.setProperties({
      topic: fakeTopic(),
      rootNodes: [makeRootNode(5)],
      firstLoadedPage: 0,
      page: 0,
      rootSummary: { page_size: 2, total: 100 },
      sort: "top",
    });
    registerStubElement(this.controller, 80, 400);

    await this.controller.jumpToRootPage(5);
    await settled();

    assert.true(this.scrollSpy.called, "scrolls to the first loaded root");
  });

  test("assigns suggested/related on final-page jump", async function (assert) {
    pretender.get("/n/demo-topic/42.json", () =>
      response({
        roots: [{ id: 300, post_number: 99 }],
        page: 9,
        has_more_roots: false,
        suggested_topics: [{ id: 1 }],
        related_topics: [{ id: 2 }],
      })
    );

    this.controller.setProperties({
      topic: fakeTopic(),
      rootNodes: [makeRootNode(5)],
      firstLoadedPage: 0,
      page: 0,
      rootSummary: { page_size: 1, total: 10 },
      sort: "top",
    });
    registerStubElement(this.controller, 99, 200);

    await this.controller.jumpToRootPage(9);
    await settled();

    assert.deepEqual(
      this.controller.topic.suggested_topics,
      [{ id: 1 }],
      "piggybacked suggested_topics attach to the topic"
    );
    assert.deepEqual(this.controller.topic.related_topics, [{ id: 2 }]);
  });

  test("does nothing while another load is in flight", async function (assert) {
    this.controller.setProperties({
      topic: fakeTopic(),
      rootNodes: [makeRootNode(5)],
      firstLoadedPage: 0,
      page: 0,
      loadingMore: true,
      sort: "top",
    });

    let ajaxCalled = false;
    pretender.get("/n/demo-topic/42.json", () => {
      ajaxCalled = true;
      return response({ roots: [], page: 0 });
    });

    await this.controller.jumpToRootPage(3, 50);

    assert.false(
      ajaxCalled,
      "guards against re-entry while loadingMore is true"
    );
  });
});
