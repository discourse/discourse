import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostList from "discourse/components/post-list";
import { cloneJSON } from "discourse/lib/object";
import PostBulkSelectHelper from "discourse/lib/post-bulk-select-helper";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import postModel from "../../fixtures/post-list";

module("Integration | Component | PostList | Index", function (hooks) {
  setupRenderingTest(hooks);

  test("@posts", async function (assert) {
    const posts = cloneJSON(postModel);
    await render(<template><PostList @posts={{posts}} /></template>);
    assert.dom(".post-list").exists();
    assert.dom(".post-list__empty-text").doesNotExist();
    assert.dom(".post-list-item").exists({ count: 2 });
  });

  test("@additionalItemClasses", async function (assert) {
    const posts = cloneJSON(postModel);
    const additionalClasses = ["first-class", "second-class"];
    await render(
      <template>
        <PostList
          @posts={{posts}}
          @additionalItemClasses={{additionalClasses}}
        />
      </template>
    );
    assert.dom(".post-list-item").hasClass("first-class");
    assert.dom(".post-list-item").hasClass("second-class");
  });

  test("@titleAriaLabel", async function (assert) {
    const posts = cloneJSON(postModel);
    const titleAriaLabel = "My custom aria title label";
    await render(
      <template>
        <PostList @posts={{posts}} @titleAriaLabel={{titleAriaLabel}} />
      </template>
    );
    assert
      .dom(".post-list-item__details .title a")
      .hasAttribute("aria-label", titleAriaLabel);
  });

  test("@emptyText", async function (assert) {
    const posts = [];
    await render(
      <template>
        <PostList @posts={{posts}} @emptyText="My custom empty text" />
      </template>
    );
    assert.dom(".post-list__empty-text").hasText("My custom empty text");
  });

  test("@showUserInfo", async function (assert) {
    const posts = cloneJSON(postModel);
    await render(
      <template><PostList @posts={{posts}} @showUserInfo={{false}} /></template>
    );
    assert.dom(".post-list-item__details .post-member-info").doesNotExist();
  });

  test("@titlePath", async function (assert) {
    const posts = cloneJSON(postModel).map((post) => {
      post.topic_html_title = `Fancy title`;
      return post;
    });
    await render(
      <template>
        <PostList @posts={{posts}} @titlePath="topic_html_title" />
      </template>
    );
    assert.dom(".post-list-item__details .title a").hasText("Fancy title");
  });

  test("@idPath", async function (assert) {
    const posts = cloneJSON(postModel).map((post) => {
      post.post_id = post.id;
      return post;
    });
    await render(
      <template><PostList @posts={{posts}} @idPath="post_id" /></template>
    );
    assert.dom(".post-list-item .excerpt").hasAttribute("data-post-id", "1");
  });

  test("@urlPath", async function (assert) {
    const posts = cloneJSON(postModel).map((post) => {
      post.postUrl = `/t/${post.topic_id}/${post.id}`;
      return post;
    });
    await render(
      <template><PostList @posts={{posts}} @urlPath="postUrl" /></template>
    );
    assert
      .dom(".post-list-item__details .title a")
      .hasAttribute("href", "/t/1/1");
  });

  test("@usernamePath", async function (assert) {
    const posts = cloneJSON(postModel).map((post) => {
      post.draft_username = "john";
      return post;
    });

    await render(
      <template>
        <PostList @posts={{posts}} @usernamePath="draft_username" />
      </template>
    );
    assert
      .dom(".post-list-item__header .avatar-link")
      .hasAttribute("data-user-card", "john");
  });

  module("bulk selection", function () {
    test("shows checkboxes when @bulkSelectEnabled is true", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      assert.dom(".bulk-select-checkbox").exists({ count: 2 });
      assert.dom(".post-list-item__bulk-select").exists({ count: 2 });
    });

    test("hides checkboxes when @bulkSelectEnabled is false", async function (assert) {
      const posts = cloneJSON(postModel);

      await render(
        <template>
          <PostList @posts={{posts}} @bulkSelectEnabled={{false}} />
        </template>
      );

      assert.dom(".bulk-select-checkbox").doesNotExist();
      assert.dom(".post-list-item__bulk-select").doesNotExist();
    });

    test("shows bulk controls only when items are selected", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      // Initially no controls should be visible
      assert.dom(".post-list-bulk-controls").doesNotExist();

      // Select a post
      await click(".bulk-select-checkbox");

      // Now controls should be visible
      assert.dom(".post-list-bulk-controls").exists();
      assert.dom(".post-list-bulk-controls__count").containsText("1");
    });

    test("selecting posts updates the selection count", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      // Select first post
      await click(".post-list-item:first-child .bulk-select-checkbox");
      assert.dom(".post-list-bulk-controls__count").containsText("1");

      // Select second post
      await click(".post-list-item:last-child .bulk-select-checkbox");
      assert.dom(".post-list-bulk-controls__count").containsText("2");
    });

    test("select all button selects all posts", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      // Select one post to show controls
      await click(".bulk-select-checkbox");

      // Click select all
      await click(".bulk-select-all");

      // All checkboxes should be checked
      assert.dom(".bulk-select-checkbox:checked").exists({ count: 2 });
      assert.dom(".post-list-bulk-controls__count").containsText("2");
    });

    test("clear all button deselects all posts", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      // Select all posts
      await click(".bulk-select-checkbox");
      await click(".bulk-select-all");

      // Clear all
      await click(".bulk-clear-all");

      // No checkboxes should be checked and controls should be hidden
      assert.dom(".bulk-select-checkbox:checked").doesNotExist();
      assert.dom(".post-list-bulk-controls").doesNotExist();
    });

    test("shows selected class on selected items", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      // Initially no items should have selected class
      assert.dom(".post-list-item--selected").doesNotExist();

      // Select first post
      await click(".post-list-item:first-child .bulk-select-checkbox");

      // First item should have selected class
      assert
        .dom(".post-list-item:first-child")
        .hasClass("post-list-item--selected");
      assert
        .dom(".post-list-item:last-child")
        .doesNotHaveClass("post-list-item--selected");
    });

    test("bulk actions dropdown appears when items are selected", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);
      const bulkActions = [
        {
          label: "test.bulk_delete",
          icon: "trash-can",
          action: () => {},
          class: "btn-danger",
        },
      ];

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
            @bulkActions={{bulkActions}}
          />
        </template>
      );

      // Initially no dropdown should be visible
      assert.dom(".bulk-actions-dropdown").doesNotExist();

      // Select a post
      await click(".bulk-select-checkbox");

      // Dropdown should now be visible
      assert.dom(".bulk-actions-dropdown").exists();
    });

    test("toggles selection when clicking checkbox", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
          />
        </template>
      );

      const checkbox = ".post-list-item:first-child .bulk-select-checkbox";

      // Initially unchecked
      assert.dom(checkbox).isNotChecked();

      // Click to select
      await click(checkbox);
      assert.dom(checkbox).isChecked();

      // Click to deselect
      await click(checkbox);
      assert.dom(checkbox).isNotChecked();
      assert.dom(".post-list-bulk-controls").doesNotExist();
    });

    test("bulk action execution calls provided action function", async function (assert) {
      const posts = cloneJSON(postModel);
      const bulkSelectHelper = new PostBulkSelectHelper(this, posts);

      let bulkActionCalled = false;
      let bulkActionPosts = null;

      const bulkActions = [
        {
          label: "test.bulk_delete",
          icon: "trash-can",
          action: (selectedPosts) => {
            bulkActionCalled = true;
            bulkActionPosts = selectedPosts;
          },
          class: "btn-danger",
        },
      ];

      await render(
        <template>
          <PostList
            @posts={{posts}}
            @bulkSelectEnabled={{true}}
            @bulkSelectHelper={{bulkSelectHelper}}
            @bulkActions={{bulkActions}}
          />
        </template>
      );

      // Select a post
      await click(".bulk-select-checkbox");

      // Open dropdown and click bulk action
      await click(".bulk-actions-dropdown");
      await click(".dropdown-menu .btn-danger");

      assert.true(bulkActionCalled, "Bulk action should have been called");
      assert.strictEqual(
        bulkActionPosts.length,
        1,
        "Should pass selected posts to action"
      );
    });
  });
});
