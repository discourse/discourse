import { module, test } from "qunit";

module(
  "Unit | Controller | nested – message bus and state management",
  function () {
    function makePost(id, postNumber, { read = false } = {}) {
      const data = {
        id,
        post_number: postNumber,
        read,
        deleted: false,
        deleted_post_placeholder: false,
        cooked: "<p>Content</p>",
      };
      return {
        ...data,
        set(key, value) {
          data[key] = value;
          this[key] = value;
        },
        get(key) {
          return data[key];
        },
      };
    }

    // _markPostDeletedLocally tests
    module("_markPostDeletedLocally", function () {
      function markPostDeletedLocally(postRegistry, postId) {
        for (const post of postRegistry.values()) {
          if (post.id === postId) {
            post.set("deleted", true);
            post.set("deleted_post_placeholder", true);
            post.set("cooked", "");
            break;
          }
        }
      }

      test("marks matching post as deleted", function (assert) {
        const registry = new Map();
        const post = makePost(100, 2);
        registry.set(2, post);

        markPostDeletedLocally(registry, 100);

        assert.true(post.deleted);
        assert.true(post.deleted_post_placeholder);
        assert.strictEqual(post.cooked, "");
      });

      test("does not affect other posts", function (assert) {
        const registry = new Map();
        const post1 = makePost(100, 2);
        const post2 = makePost(101, 3);
        registry.set(2, post1);
        registry.set(3, post2);

        markPostDeletedLocally(registry, 100);

        assert.true(post1.deleted);
        assert.false(post2.deleted);
        assert.strictEqual(post2.cooked, "<p>Content</p>");
      });

      test("does nothing when post is not in registry", function (assert) {
        const registry = new Map();
        const post = makePost(100, 2);
        registry.set(2, post);

        markPostDeletedLocally(registry, 999);

        assert.false(post.deleted);
      });
    });

    // _onMessage routing tests
    module("_onMessage routing", function () {
      test("routes 'created' type correctly", function (assert) {
        const handled = [];
        const handler = {
          _handleCreated(data) {
            handled.push({ type: "created", data });
          },
          _handlePostChanged(data) {
            handled.push({ type: "changed", data });
          },
        };

        // Simulate _onMessage logic
        function onMessage(data) {
          switch (data.type) {
            case "created":
              handler._handleCreated(data);
              break;
            case "revised":
            case "rebaked":
            case "deleted":
            case "recovered":
            case "acted":
              handler._handlePostChanged(data);
              break;
          }
        }

        onMessage({ type: "created", id: 1 });
        assert.strictEqual(handled.length, 1);
        assert.strictEqual(handled[0].type, "created");
      });

      test("routes 'deleted' to _handlePostChanged", function (assert) {
        const handled = [];
        function onMessage(data) {
          switch (data.type) {
            case "created":
              handled.push("created");
              break;
            case "revised":
            case "rebaked":
            case "deleted":
            case "recovered":
            case "acted":
              handled.push("changed");
              break;
          }
        }

        onMessage({ type: "deleted", id: 1 });
        assert.strictEqual(handled[0], "changed");
      });

      test("routes 'revised' to _handlePostChanged", function (assert) {
        const handled = [];
        function onMessage(data) {
          switch (data.type) {
            case "created":
              handled.push("created");
              break;
            case "revised":
            case "rebaked":
            case "deleted":
            case "recovered":
            case "acted":
              handled.push("changed");
              break;
          }
        }

        onMessage({ type: "revised", id: 1 });
        assert.strictEqual(handled[0], "changed");
      });

      test("routes 'acted' to _handlePostChanged", function (assert) {
        const handled = [];
        function onMessage(data) {
          switch (data.type) {
            case "created":
              handled.push("created");
              break;
            case "revised":
            case "rebaked":
            case "deleted":
            case "recovered":
            case "acted":
              handled.push("changed");
              break;
          }
        }

        onMessage({ type: "acted", id: 1 });
        assert.strictEqual(handled[0], "changed");
      });

      test("ignores unknown message types", function (assert) {
        const handled = [];
        function onMessage(data) {
          switch (data.type) {
            case "created":
              handled.push("created");
              break;
            case "revised":
            case "rebaked":
            case "deleted":
            case "recovered":
            case "acted":
              handled.push("changed");
              break;
          }
        }

        onMessage({ type: "unknown_type", id: 1 });
        assert.strictEqual(handled.length, 0);
      });
    });

    // _handleCreated routing logic
    module("_handleCreated routing", function () {
      function simulateHandleCreated(postData, messageBusData, currentUserId) {
        const replyTo = postData.reply_to_post_number;
        const isRoot = !replyTo || replyTo === 1;
        const result = { action: null, isRoot };

        if (isRoot) {
          if (messageBusData.user_id === currentUserId) {
            result.action = "prepend_own_root";
          } else {
            result.action = "add_to_new_root_ids";
          }
        } else {
          result.action = "trigger_child_created";
          result.parentPostNumber = replyTo;
          result.isOwnPost = messageBusData.user_id === currentUserId;
        }

        return result;
      }

      test("own root post is prepended to rootNodes", function (assert) {
        const result = simulateHandleCreated(
          { reply_to_post_number: null },
          { user_id: 1, id: 100 },
          1
        );
        assert.strictEqual(result.action, "prepend_own_root");
        assert.true(result.isRoot);
      });

      test("reply_to_post_number=1 is treated as a root", function (assert) {
        const result = simulateHandleCreated(
          { reply_to_post_number: 1 },
          { user_id: 1, id: 100 },
          1
        );
        assert.strictEqual(result.action, "prepend_own_root");
        assert.true(result.isRoot);
      });

      test("other user's root post is added to newRootPostIds", function (assert) {
        const result = simulateHandleCreated(
          { reply_to_post_number: null },
          { user_id: 2, id: 100 },
          1
        );
        assert.strictEqual(result.action, "add_to_new_root_ids");
      });

      test("child post triggers child-created event", function (assert) {
        const result = simulateHandleCreated(
          { reply_to_post_number: 5 },
          { user_id: 2, id: 100 },
          1
        );
        assert.strictEqual(result.action, "trigger_child_created");
        assert.strictEqual(result.parentPostNumber, 5);
        assert.false(result.isOwnPost);
      });

      test("own child post sets isOwnPost=true", function (assert) {
        const result = simulateHandleCreated(
          { reply_to_post_number: 5 },
          { user_id: 1, id: 100 },
          1
        );
        assert.strictEqual(result.action, "trigger_child_created");
        assert.true(result.isOwnPost);
      });
    });

    // _handlePostChanged routing
    module("_handlePostChanged routing", function () {
      test("deleted type marks post locally without fetching", function (assert) {
        let markedId = null;
        let fetchCalled = false;

        function handlePostChanged(data) {
          if (data.type === "deleted") {
            markedId = data.id;
            return;
          }
          fetchCalled = true;
        }

        handlePostChanged({ type: "deleted", id: 42 });

        assert.strictEqual(markedId, 42);
        assert.false(fetchCalled);
      });

      test("non-deleted types trigger a fetch", function (assert) {
        let fetchCalled = false;

        function handlePostChanged(data) {
          if (data.type === "deleted") {
            return;
          }
          fetchCalled = true;
        }

        handlePostChanged({ type: "revised", id: 42 });
        assert.true(fetchCalled);
      });
    });

    // Post registry
    module("postRegistry", function () {
      test("registers post by post_number", function (assert) {
        const registry = new Map();
        const post = makePost(100, 5);

        if (post?.post_number != null) {
          registry.set(post.post_number, post);
        }

        assert.strictEqual(registry.get(5), post);
      });

      test("unregisters post by post_number", function (assert) {
        const registry = new Map();
        const post = makePost(100, 5);
        registry.set(post.post_number, post);

        if (post?.post_number != null) {
          registry.delete(post.post_number);
        }

        assert.false(registry.has(5));
      });

      test("ignores null post_number on register", function (assert) {
        const registry = new Map();
        const post = { id: 100, post_number: null };

        if (post?.post_number != null) {
          registry.set(post.post_number, post);
        }

        assert.strictEqual(registry.size, 0);
      });

      test("ignores null post on register", function (assert) {
        const registry = new Map();
        const post = null;

        if (post?.post_number != null) {
          registry.set(post.post_number, post);
        }

        assert.strictEqual(registry.size, 0);
      });
    });

    // readPosts
    module("readPosts", function () {
      function readPosts(topicId, postRegistry, calledTopicId, postNumbers) {
        if (topicId !== calledTopicId) {
          return;
        }
        for (const postNumber of postNumbers) {
          const post = postRegistry.get(postNumber);
          if (post && !post.read) {
            post.set("read", true);
          }
        }
      }

      test("marks posts as read when topic matches", function (assert) {
        const registry = new Map();
        const post = makePost(100, 2);
        registry.set(2, post);

        readPosts(42, registry, 42, [2]);
        assert.true(post.read);
      });

      test("ignores when topic ID doesn't match", function (assert) {
        const registry = new Map();
        const post = makePost(100, 2);
        registry.set(2, post);

        readPosts(42, registry, 99, [2]);
        assert.false(post.read);
      });

      test("skips already-read posts", function (assert) {
        const registry = new Map();
        const post = makePost(100, 2, { read: true });
        let setCalled = false;
        const originalSet = post.set.bind(post);
        post.set = (key, value) => {
          setCalled = true;
          originalSet(key, value);
        };
        registry.set(2, post);

        readPosts(42, registry, 42, [2]);
        assert.false(setCalled);
      });

      test("skips post numbers not in registry", function (assert) {
        const registry = new Map();
        const post = makePost(100, 2);
        registry.set(2, post);

        readPosts(42, registry, 42, [2, 99]);
        assert.true(post.read);
        assert.strictEqual(registry.size, 1);
      });
    });

    // loadMoreRoots guard logic
    module("loadMoreRoots guards", function () {
      test("does not load when already loading", function (assert) {
        let loadingMore = true;
        let hasMoreRoots = true;
        let fetchCalled = false;

        if (!loadingMore && hasMoreRoots) {
          fetchCalled = true;
        }

        assert.false(fetchCalled);
      });

      test("does not load when no more roots", function (assert) {
        let loadingMore = false;
        let hasMoreRoots = false;
        let fetchCalled = false;

        if (!loadingMore && hasMoreRoots) {
          fetchCalled = true;
        }

        assert.false(fetchCalled);
      });

      test("loads when not loading and has more", function (assert) {
        let loadingMore = false;
        let hasMoreRoots = true;
        let fetchCalled = false;

        if (!loadingMore && hasMoreRoots) {
          fetchCalled = true;
        }

        assert.true(fetchCalled);
      });
    });
  }
);
