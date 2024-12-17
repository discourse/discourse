import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostList from "discourse/components/post-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import postModel from "../../fixtures/post-list";

module("Integration | Component | PostList | Index", function (hooks) {
  setupRenderingTest(hooks);

  test("@posts", async function (assert) {
    const posts = postModel;
    await render(<template><PostList @posts={{posts}} /></template>);
    assert.dom(".post-list").exists();
    assert.dom(".post-list__empty-text").doesNotExist();
    assert.dom(".post-list-item").exists({ count: 2 });
  });

  test("@additionalItemClasses", async function (assert) {
    const posts = postModel;
    const additionalClasses = ["first-class", "second-class"];
    await render(<template>
      <PostList @posts={{posts}} @additionalItemClasses={{additionalClasses}} />
    </template>);
    assert.dom(".post-list-item").hasClass("first-class");
    assert.dom(".post-list-item").hasClass("second-class");
  });

  test("@titleAriaLabel", async function (assert) {
    const posts = postModel;
    const titleAriaLabel = "My custom aria title label";
    await render(<template>
      <PostList @posts={{posts}} @titleAriaLabel={{titleAriaLabel}} />
    </template>);
    assert
      .dom(".post-list-item__details .title a")
      .hasAttribute("aria-label", titleAriaLabel);
  });

  test("@emptyText", async function (assert) {
    const posts = [];
    await render(<template>
      <PostList @posts={{posts}} @emptyText="My custom empty text" />
    </template>);
    assert.dom(".post-list__empty-text").hasText("My custom empty text");
  });
});
