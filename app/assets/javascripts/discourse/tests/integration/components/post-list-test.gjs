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

  test("@showUserInfo", async function (assert) {
    const posts = postModel;
    await render(<template>
      <PostList @posts={{posts}} @showUserInfo={{false}} />
    </template>);
    assert.dom(".post-list-item__details .post-member-info").doesNotExist();
  });

  test("@titlePath", async function (assert) {
    const posts = postModel.map((post) => {
      post.topic_html_title = `Fancy title`;
      return post;
    });
    await render(<template>
      <PostList @posts={{posts}} @titlePath="topic_html_title" />
    </template>);
    assert.dom(".post-list-item__details .title a").hasText("Fancy title");
  });

  test("@idPath", async function (assert) {
    const posts = postModel.map((post) => {
      post.post_id = post.id;
      return post;
    });
    await render(<template>
      <PostList @posts={{posts}} @idPath="post_id" />
    </template>);
    assert.dom(".post-list-item .excerpt").hasAttribute("data-post-id", "1");
  });

  test("@urlPath", async function (assert) {
    const posts = postModel.map((post) => {
      post.postUrl = `/t/${post.topic_id}/${post.id}`;
      return post;
    });
    await render(<template>
      <PostList @posts={{posts}} @urlPath="postUrl" />
    </template>);
    assert
      .dom(".post-list-item__details .title a")
      .hasAttribute("href", "/t/1/1");
  });

  test("@usernamePath", async function (assert) {
    const posts = postModel.map((post) => {
      post.draft_username = "john";
      return post;
    });

    await render(<template>
      <PostList @posts={{posts}} @usernamePath="draft_username" />
    </template>);
    assert
      .dom(".post-list-item__header .avatar-link")
      .hasAttribute("data-user-card", "john");
  });
});
