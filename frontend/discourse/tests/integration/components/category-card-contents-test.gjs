import { click, render, triggerEvent, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import CategoryCardContents from "discourse/components/category-card-contents";
import { forceMobile } from "discourse/lib/mobile";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | CategoryCardContents", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/c/*path", () => response({ topic_list: { topics: [] } }));
  });

  test("opens from a category hashtag and closes on an outside click", async function (assert) {
    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="2"
            data-type="category"
            href="/c/product/2"
          >#product</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card .card-content").exists("the card opens");

    await triggerEvent("#main-outlet", "pointerdown");

    assert.dom(".category-card .card-content").doesNotExist("the card closes");
  });

  test("lazy loads a category outside a post and reuses it on reopening", async function (assert) {
    this.site.set("lazy_load_categories", true);
    const requestedIds = [];

    pretender.get("/categories/find", (request) => {
      requestedIds.push(request.queryParams.ids);
      return response({
        categories: [
          { id: 12345, name: "Lazy category", slug: "lazy-category" },
        ],
      });
    });

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12345"
            data-type="category"
            href="/c/lazy-category/12345"
          >#lazy-category</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.deepEqual(
      requestedIds,
      [["12345"]],
      "the hashtag ID is lazy loaded"
    );
    assert.strictEqual(
      Category.findById(12345).name,
      "Lazy category",
      "the category model is available"
    );
    assert
      .dom(".category-card .card-content")
      .exists("the card opens without a topic or post");

    await triggerEvent("#main-outlet", "pointerdown");
    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card .card-content").exists("the card reopens");
    assert.strictEqual(requestedIds.length, 1, "the loaded category is reused");
  });

  test("offers a new topic button only where the user can create topics", async function (assert) {
    this.site.set("lazy_load_categories", true);
    this.owner.lookup("service:current-user").set("can_create_topic", true);
    const composer = { openNewTopic: sinon.stub() };
    this.owner.unregister("service:composer");
    this.owner.register("service:composer", composer, { instantiate: false });

    pretender.get("/categories/find", (request) => {
      const id = Number(request.queryParams.ids[0]);

      return response({
        categories: [
          {
            id,
            name: "Writable",
            slug: "writable",
            permission: id === 12348 ? PermissionType.FULL : null,
          },
        ],
      });
    });

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked writable-hashtag"
            data-id="12348"
            data-type="category"
            href="/c/writable/12348"
          >#writable</a>
          <a
            class="hashtag-cooked readonly-hashtag"
            data-id="12349"
            data-type="category"
            href="/c/writable/12349"
          >#readonly</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click(".readonly-hashtag");

    assert
      .dom(".category-card__new-topic")
      .doesNotExist("hidden without create permission on the category");

    await triggerEvent("#main-outlet", "pointerdown");
    await click(".writable-hashtag");
    await click(".category-card__new-topic");

    assert.true(composer.openNewTopic.calledOnce, "opens the composer");
    assert.strictEqual(
      composer.openNewTopic.firstCall?.args[0].category.id,
      12348,
      "the composer targets the card's category"
    );
    assert.dom(".category-card .card-content").doesNotExist("closes the card");
  });

  test("hides the new topic button when the user cannot create topics", async function (assert) {
    this.site.set("lazy_load_categories", true);
    this.owner.lookup("service:current-user").set("can_create_topic", false);

    pretender.get("/categories/find", () =>
      response({
        categories: [
          {
            id: 12350,
            name: "Writable",
            slug: "writable",
            permission: PermissionType.FULL,
          },
        ],
      })
    );

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12350"
            data-type="category"
            href="/c/writable/12350"
          >#writable</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card .card-content").exists("the card opens");
    assert.dom(".category-card__new-topic").doesNotExist();
  });

  test("shows admins an edit description link, even without a description", async function (assert) {
    this.site.set("lazy_load_categories", true);
    const currentUser = this.owner.lookup("service:current-user");

    pretender.get("/categories/find", () =>
      response({
        categories: [
          {
            id: 12351,
            name: "Undescribed",
            slug: "undescribed",
            topic_url: "/t/about-the-undescribed-category/99",
          },
        ],
      })
    );

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12351"
            data-type="category"
            href="/c/undescribed/12351"
          >#undescribed</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    currentUser.set("admin", true);
    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card .bio").doesNotExist("there is no description");
    assert
      .dom(".category-card__edit-description")
      .hasAttribute("href", "/t/about-the-undescribed-category/99");

    await triggerEvent("#main-outlet", "pointerdown");
    currentUser.set("admin", false);
    await click('a.hashtag-cooked[data-type="category"]');

    assert
      .dom(".category-card__edit-description")
      .doesNotExist("hidden from non-admins");
  });

  test("applies the create topic label and icon transformers to the new topic button", async function (assert) {
    this.site.set("lazy_load_categories", true);
    this.owner.lookup("service:current-user").set("can_create_topic", true);

    withPluginApi((api) => {
      api.registerValueTransformer(
        "create-topic-label",
        ({ value, context }) =>
          context.category?.id === 12352 ? "topic.create_long" : value
      );
      api.registerValueTransformer("create-topic-icon", () => "plus");
    });

    pretender.get("/categories/find", () =>
      response({
        categories: [
          {
            id: 12352,
            name: "Events",
            slug: "events",
            permission: PermissionType.FULL,
          },
        ],
      })
    );

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12352"
            data-type="category"
            href="/c/events/12352"
          >#events</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card__new-topic").hasText("Create a new topic");
    assert.dom(".category-card__new-topic .d-icon-plus").exists();
  });

  test("edit description opens the composer on the about topic's first post", async function (assert) {
    this.site.set("lazy_load_categories", true);
    this.owner.lookup("service:current-user").set("admin", true);
    const composer = { open: sinon.stub() };
    this.owner.unregister("service:composer");
    this.owner.register("service:composer", composer, { instantiate: false });

    pretender.get("/categories/find", () =>
      response({
        categories: [
          {
            id: 12354,
            name: "Editable",
            slug: "editable",
            topic_url: "/t/about-the-editable-category/98",
          },
        ],
      })
    );
    pretender.get("/t/about-the-editable-category/98.json", () =>
      response({
        id: 98,
        title: "About the Editable category",
        draft_key: "topic_98",
        draft_sequence: 3,
        post_stream: {
          posts: [{ id: 555, post_number: 1, topic_id: 98 }],
          stream: [555],
        },
      })
    );

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12354"
            data-type="category"
            href="/c/editable/12354"
          >#editable</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');
    await click(".category-card__edit-description");

    assert.true(composer.open.calledOnce, "opens the composer");

    const opts = composer.open.firstCall?.args[0];
    assert.strictEqual(opts?.action, "edit");
    assert.strictEqual(opts?.post.id, 555, "edits the first post");
    assert.strictEqual(opts?.draftKey, "topic_98");
    assert.dom(".category-card .card-content").doesNotExist("closes the card");
  });

  test("lists the category's latest topics and reuses them on reopening", async function (assert) {
    this.site.set("lazy_load_categories", true);
    const latestRequests = [];

    pretender.get("/categories/find", () =>
      response({
        categories: [
          {
            id: 12355,
            name: "Busy",
            slug: "busy",
            topic_url: "/t/about-the-busy-category/700",
          },
        ],
      })
    );
    pretender.get("/c/busy/12355/l/latest.json", (request) => {
      latestRequests.push(request.queryParams);
      return response({
        topic_list: {
          topics: [
            {
              id: 700,
              slug: "about-the-busy-category",
              fancy_title: "About the Busy category",
              bumped_at: "2026-09-02T00:00:00.000Z",
              posters: [],
            },
            {
              id: 701,
              slug: "first-topic",
              fancy_title: "First topic",
              bumped_at: "2026-09-01T00:00:00.000Z",
              posters: [],
            },
            {
              id: 702,
              slug: "second-topic",
              fancy_title: "Second topic",
              bumped_at: "2026-08-01T00:00:00.000Z",
              posters: [],
            },
          ],
        },
      });
    });

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12355"
            data-type="category"
            href="/c/busy/12355"
          >#busy</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card__topics .featured-topic").exists({ count: 2 });
    assert
      .dom(".category-card__topics .featured-topic .title")
      .hasAttribute("href", /^\/t\/first-topic\/701/)
      .hasText("First topic");
    assert
      .dom(".category-card__topics")
      .doesNotIncludeText(
        "About the Busy category",
        "leaves out the about topic"
      );
    assert.strictEqual(
      latestRequests[0]?.per_page,
      "4",
      "asks for one extra topic to cover the about topic"
    );

    await triggerEvent("#main-outlet", "pointerdown");
    await click('a.hashtag-cooked[data-type="category"]');

    assert
      .dom(".category-card__topics .featured-topic")
      .exists({ count: 2 }, "the reopened card lists the topics");
    assert.strictEqual(latestRequests.length, 1, "the list is cached");
  });
});

module(
  "Integration | Component | CategoryCardContents | Anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    async function renderStaffHashtag() {
      await render(
        <template>
          <div id="main-outlet">
            <a
              class="hashtag-cooked"
              data-id="123456"
              data-type="category"
              href="/c/staff/123456"
            >#staff</a>
          </div>
          <div class="card-cloak"></div>
          <CategoryCardContents />
        </template>
      );
    }

    for (const mobileView of [false, true]) {
      for (const status of [null, 200, 403, 404]) {
        test(`navigates without opening a popup for an inaccessible category (${mobileView ? "mobile" : "desktop"}, ${status ?? "preloaded"})`, async function (assert) {
          if (mobileView) {
            forceMobile();
          }
          this.site.set("lazy_load_categories", status !== null);
          const routeTo = sinon.stub(DiscourseURL, "routeTo");

          if (status !== null) {
            pretender.get("/categories/find", () =>
              response(status, { categories: [] })
            );
          }

          await renderStaffHashtag();
          const createMenu = sinon.spy(
            this.owner.lookup("service:menu"),
            "newInstance"
          );
          await click('a.hashtag-cooked[data-type="category"]');

          assert.true(
            routeTo.calledOnceWithExactly(
              `${window.location.origin}/c/staff/123456`
            ),
            "the original category URL handles the unavailable category"
          );
          assert.false(createMenu.called, "no floating menu is ever created");
          assert
            .dom('.fk-d-menu[data-identifier="category-card"]')
            .doesNotExist("no empty popup remains");
          assert
            .dom(".category-card .card-content")
            .doesNotExist("no category content is shown");
          assert
            .dom(".card-cloak")
            .doesNotHaveClass("--visible", "no mobile cloak is shown");
        });
      }
    }

    for (const accessible of [false, true]) {
      test(`navigation during lookup does not reopen or redirect (accessible: ${accessible})`, async function (assert) {
        this.site.set("lazy_load_categories", true);
        const routeTo = sinon.stub(DiscourseURL, "routeTo");
        let releaseLookup;

        pretender.get("/categories/find", async () => {
          await new Promise((resolve) => (releaseLookup = resolve));
          return response({
            categories: accessible
              ? [{ id: 123456, name: "Staff", slug: "staff" }]
              : [],
          });
        });

        await renderStaffHashtag();
        const opening = click('a.hashtag-cooked[data-type="category"]');
        await waitUntil(() => releaseLookup);

        assert
          .dom('.fk-d-menu[data-identifier="category-card"]')
          .doesNotExist("no popup opens while access is unresolved");
        assert
          .dom(".category-card .card-content")
          .doesNotExist("no content is shown while loading");

        this.owner.lookup("service:app-events").trigger("dom:clean");
        releaseLookup();
        await opening;

        assert.false(routeTo.called, "a cancelled lookup does not navigate");
        assert
          .dom('.fk-d-menu[data-identifier="category-card"]')
          .doesNotExist("a cancelled lookup does not open a popup");
        assert
          .dom(".category-card .card-content")
          .doesNotExist("the card stays closed");
      });
    }
  }
);
