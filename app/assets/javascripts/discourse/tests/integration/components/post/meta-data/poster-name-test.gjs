import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMetaDataPosterName from "discourse/components/post/meta-data/poster-name";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function renderComponent(post) {
  return render(<template><PostMetaDataPosterName @post={{post}} /></template>);
}

module(
  "Integration | Component | Post | PostMetaDataPosterName",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.glimmer_post_stream_mode = "enabled";

      this.store = getOwner(this).lookup("service:store");
      const topic = this.store.createRecord("topic", { id: 1 });
      const post = this.store.createRecord("post", {
        id: 123,
        post_number: 1,
        topic,
        like_count: 3,
        actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
      });

      this.post = post;
    });

    test("basic rendering", async function (assert) {
      this.post.username = "eviltrout";
      this.post.name = "Robin Ward";
      this.post.user_title = "Trout Master";

      await renderComponent(this.post);

      assert.dom(".names").exists();
      assert.dom("span.username").exists();
      assert
        .dom('a[data-user-card="eviltrout"]')
        .exists()
        .hasAttribute("href", "/u/eviltrout");
      assert.dom(".username a").hasText("eviltrout");
      assert.dom(".user-title").hasText("Trout Master");
    });

    test("extra classes and glyphs", async function (assert) {
      this.post.username = "eviltrout";
      this.post.staff = true;
      this.post.admin = true;
      this.post.moderator = true;
      this.post.trust_level = 0;
      this.post.primary_group_name = "fish";

      await renderComponent(this.post);

      assert.dom("span.staff").exists();
      assert.dom("span.admin").exists();
      assert.dom("span.moderator").exists();
      assert.dom(".d-icon-shield-halved").exists();
      assert.dom("span.new-user").exists();
      assert.dom("span.group--fish").exists();
    });

    test("disable display name on posts", async function (assert) {
      this.siteSettings.display_name_on_posts = false;
      this.post.username = "eviltrout";
      this.post.name = "Robin Ward";

      await renderComponent(this.post);

      assert.dom(".full-name").doesNotExist();
    });

    test("doesn't render a name if it's similar to the username", async function (assert) {
      this.siteSettings.prioritize_username_in_ux = true;
      this.siteSettings.display_name_on_posts = true;
      this.post.username = "eviltrout";
      this.post.name = "evil-trout";

      await renderComponent(this.post);

      assert
        .dom(".second")
        .doesNotExist("similar names are suppressed by default");

      // the transformer can change this behavior
      withPluginApi((api) => {
        api.registerValueTransformer(
          "post-meta-data-poster-name-suppress-similar-name",
          () => false
        );
      });

      await renderComponent(this.post);

      assert
        .dom(".second")
        .exists(
          "suppresing similar names can changed using the post-meta-data-poster-name-suppress-similar-name transformer"
        );
    });

    test("renders badges that are passed in", async function (assert) {
      this.post.username = "eviltrout";
      this.post.user = this.store.createRecord("user", {
        username: "eviltrout",
      });
      this.post.badges_granted = [
        { badge: { id: 1, icon: "heart", slug: "badge1", name: "Badge One" } },
        { badge: { id: 2, icon: "target", slug: "badge2", name: "Badge Two" } },
      ];

      await renderComponent(this.post);

      // Check that the custom CSS classes are set
      assert.dom("span.user-badge-button-badge1").exists();
      assert.dom("span.user-badge-button-badge2").exists();

      // Check that the custom titles are set
      assert.dom("span.user-badge[title*='Badge One']").exists();
      assert.dom("span.user-badge[title*='Badge Two']").exists();

      // Check that the badges link to the correct badge page
      assert
        .dom(
          "a.user-card-badge-link[href='/badges/1/badge1?username=eviltrout']"
        )
        .exists();
      assert
        .dom(
          "a.user-card-badge-link[href='/badges/2/badge2?username=eviltrout']"
        )
        .exists();
    });

    test("api.addPosterIcons", async function (assert) {
      this.post.username = "eviltrout";
      this.post.user = this.store.createRecord("user", {
        username: "eviltrout",
      });

      withPluginApi((api) => {
        api.addPosterIcons((_, { username }) => {
          return [
            {
              className: "test-icon",
              icon: "cake-candles",
              title: `${username}`,
              text: "Test icon",
            },
            {
              className: "test-smile",
              emoji: "heart|smile",
              emojiTitle: "test emojis",
              url: "/u/eviltrout",
              title: `${username}`,
            },
          ];
        });
      });

      await renderComponent(this.post);

      assert
        .dom("span.poster-icon.test-icon")
        .exists()
        .hasAttribute("title", this.post.username)
        .hasText("Test icon");
      assert.dom("span.poster-icon.test-icon > .d-icon-cake-candles").exists();

      assert
        .dom("span.poster-icon.test-smile")
        .exists()
        .hasAttribute("title", this.post.username);
      assert
        .dom("span.poster-icon.test-smile > a")
        .exists()
        .hasAttribute("href", "/u/eviltrout");
      assert
        .dom("span.poster-icon.test-smile > a > .emoji[alt='heart']")
        .exists();
      assert
        .dom("span.poster-icon.test-smile > a > .emoji[alt='smile']")
        .exists();
    });

    test("poster name additional classes", async function (assert) {
      this.post.username = "eviltrout";
      this.post.user = this.store.createRecord("user", {
        username: "eviltrout",
      });
      withPluginApi((api) => {
        api.registerValueTransformer(
          "poster-name-class",
          ({ value, context }) => {
            if (context.user.username === "eviltrout") {
              value.push(...["custom-class", "another-class"]);
            }
            return value;
          }
        );
      });

      await renderComponent(this.post);
      assert.dom("span.custom-class").exists();
      assert.dom("span.another-class").exists();
    });
  }
);
