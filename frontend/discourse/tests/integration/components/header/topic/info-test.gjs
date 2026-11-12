import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import TopicInfo from "discourse/components/header/topic/info";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function createTopic(context, attrs = {}) {
  return context.store.createRecord("topic", {
    id: 1,
    slug: "header-title-topic",
    title: "Header title topic",
    fancy_title: "Header title topic",
    details: {
      allowed_groups: [],
      allowed_users: [],
      loaded: false,
    },
    ...attrs,
  });
}

function renderComponent(context) {
  return render(
    <template><TopicInfo @topicInfo={{context.topic}} /></template>
  );
}

module("Integration | Component | Header | Topic | Info", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
    this.routeTo = sinon.stub(DiscourseURL, "routeTo");
  });

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("routes flat topic title clicks to the first post", async function (assert) {
    this.topic = createTopic(this);

    await renderComponent(this);
    await click(".topic-link");

    assert.true(this.routeTo.calledOnce, "routes the title click");
    assert.strictEqual(
      this.routeTo.firstCall.args[0],
      "/t/header-title-topic/1/1",
      "routes to the first post URL"
    );
    assert.deepEqual(
      this.routeTo.firstCall.args[1],
      { keepFilter: true },
      "keeps the current topic filter"
    );
  });

  test("does not route nested topic title clicks to the first post", async function (assert) {
    this.topic = createTopic(this, { is_nested_view: true });

    await renderComponent(this);
    await click(".topic-link");

    assert.true(
      this.routeTo.notCalled,
      "does not route nested header title clicks through the post URL"
    );
  });
});
