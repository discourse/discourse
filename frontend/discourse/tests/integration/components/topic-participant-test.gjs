import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicParticipant from "discourse/components/topic-map/topic-participant";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-participant", function (hooks) {
  setupRenderingTest(hooks);

  test("one post", async function (assert) {
    const args = {
      username: "test",
      avatar_template: "/images/avatar.png",
      post_count: 1,
    };

    await render(
      <template><TopicParticipant @participant={{args}} /></template>
    );

    assert.dom("a.poster.trigger-user-card").hasAttribute("href", "/u/test");
    assert.dom("span.post-count").doesNotExist();
    assert.dom(".avatar-flair").doesNotExist();
  });

  test("many posts, a primary group with flair", async function (assert) {
    const args = {
      username: "test",
      avatar_template: "/images/avatar.png",
      post_count: 2,
      primary_group_name: "devs",
      flair_name: "devs",
      flair_url: "/images/d-logo-sketch-small.png",
      flair_bg_color: "222",
      flair_group_id: "41",
    };

    await render(
      <template><TopicParticipant @participant={{args}} /></template>
    );

    assert.dom("a.poster.trigger-user-card").hasAttribute("href", "/u/test");
    assert.dom("span.post-count").exists();
    assert.dom(".group-devs a.poster").exists();
    assert.dom(".avatar-flair.avatar-flair-devs").exists();
  });
});
