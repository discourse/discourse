import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dTopicLink from "discourse/ui-kit/helpers/d-topic-link";

function buildTopic(attrs = {}) {
  return {
    id: 42,
    fancyTitle: "A <em>fancy</em> title",
    lastUnreadUrl: "/t/a-topic/42/3",
    visited: false,
    urlForPostNumber: (postNumber) => `/t/a-topic/42/${postNumber}`,
    get(key) {
      return this[key];
    },
    ...attrs,
  };
}

module("Integration | ui-kit | Helper | dTopicLink", function (hooks) {
  setupRenderingTest(hooks);

  test("links the fancy title to the last unread post", async function (assert) {
    const topic = buildTopic();

    await render(<template>{{dTopicLink topic}}</template>);

    assert.dom("a.title").hasAttribute("href", "/t/a-topic/42/3");
    assert.dom("a.title").hasAttribute("data-topic-id", "42");
    assert.dom("a.title em").hasText("fancy");
    assert.dom("a.title .sr-only").doesNotExist();
  });

  test("links to the linked post when there is one", async function (assert) {
    const topic = buildTopic({ linked_post_number: 7 });

    await render(<template>{{dTopicLink topic}}</template>);

    assert.dom("a.title").hasAttribute("href", "/t/a-topic/42/7");
  });

  test("adds the classes", async function (assert) {
    const topic = buildTopic();

    await render(
      <template>{{dTopicLink topic class="gizmo gadget"}}</template>
    );

    assert.dom("a.title.gizmo.gadget").exists();
  });

  test("tells screen readers that a visited topic was read", async function (assert) {
    const topic = buildTopic({ visited: true });

    await render(<template>{{dTopicLink topic}}</template>);

    assert.dom("a.title .sr-only").includesText("read");
  });
});
