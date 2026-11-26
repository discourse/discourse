import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostStreamViewportTracker, {
  disableCloaking,
  enableCloaking,
  preventCloaking,
} from "discourse/modifiers/post-stream-viewport-tracker";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function postSelector(post, { cloaked }) {
  const selector = `[data-post-number="${post.post_number}"]`;

  return cloaked
    ? `${selector}.post-stream--cloaked`
    : `${selector}:not(.post-stream--cloaked)`;
}

module(
  "Integration | Modifier | post-stream-viewport-tracker",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      enableCloaking();

      const tracker = new PostStreamViewportTracker();
      const posts = [1, 2, 3, 4, 5].map((number) => ({
        id: 100 + number,
        post_number: number,
      }));

      const evaluations = new Map();
      const getCloakingData = (post) => {
        evaluations.set(post, (evaluations.get(post) ?? 0) + 1);
        return tracker.getCloakingData(post);
      };

      // The tracker is not set up, so no intersection observer exists and the
      // tests fully control which posts are inside the cloaking area.
      await render(
        <template>
          <div class="posts">
            {{#each posts key="id" as |post|}}
              {{#let (getCloakingData post) as |cloakingData|}}
                <div
                  class={{if cloakingData.active "post-stream--cloaked"}}
                  data-post-number={{post.post_number}}
                  style={{cloakingData.style}}
                  {{tracker.registerPost post}}
                >
                  {{#unless cloakingData.active}}
                    <div style="height: 50px"></div>
                  {{/unless}}
                </div>
              {{/let}}
            {{/each}}
          </div>
        </template>
      );

      let styleMutations = [];
      const mutations = new MutationObserver((records) =>
        styleMutations.push(...records)
      );
      mutations.observe(this.element.querySelector(".posts"), {
        subtree: true,
        attributeFilter: ["style"],
      });

      this.tracker = tracker;
      this.posts = posts;
      this.evaluations = evaluations;
      this.mutations = mutations;

      this.moveInsideCloakingArea = (post, isIntersecting) => {
        tracker.trackCloakedPosts({
          target: this.element.querySelector(
            `[data-post-number="${post.post_number}"]`
          ),
          isIntersecting,
          intersectionRatio: isIntersecting ? 1 : 0,
          intersectionRect: { height: isIntersecting ? 50 : 0 },
        });
      };

      this.styleMutatedPostNumbers = () => {
        const records = [...styleMutations, ...mutations.takeRecords()];
        styleMutations = [];
        return records.map((record) =>
          Number(record.target.dataset.postNumber)
        );
      };

      // posts 1 and 2 are scrolled out of the cloaking area
      this.moveInsideCloakingArea(posts[0], false);
      this.moveInsideCloakingArea(posts[1], false);
      this.moveInsideCloakingArea(posts[2], true);
      this.moveInsideCloakingArea(posts[3], true);
      this.moveInsideCloakingArea(posts[4], true);

      await waitFor(postSelector(posts[1], { cloaked: true }));
      await settled();

      evaluations.clear();
      this.styleMutatedPostNumbers();
    });

    hooks.afterEach(function () {
      this.mutations.disconnect();
      this.tracker.destroy();
      disableCloaking();
    });

    test("cloaks the posts outside the cloaking area preserving their size", async function (assert) {
      const [post1, post2, post3] = this.posts;

      assert
        .dom(postSelector(post1, { cloaked: true }))
        .hasAttribute("style", /height:[\d.]+px/, "post 1 is cloaked");
      assert
        .dom(postSelector(post2, { cloaked: true }))
        .hasAttribute("style", /height:[\d.]+px/, "post 2 is cloaked");
      assert
        .dom(postSelector(post3, { cloaked: false }))
        .doesNotHaveAttribute("style", "post 3 is not cloaked");
    });

    test("only rerenders the posts whose cloaking state changed", async function (assert) {
      const [post1, post2, post3] = this.posts;

      this.moveInsideCloakingArea(post3, false);
      await waitFor(postSelector(post3, { cloaked: true }));
      await settled();

      assert.deepEqual(
        [...this.evaluations],
        [[post3, 1]],
        "only the newly cloaked post is evaluated"
      );
      assert.deepEqual(
        this.styleMutatedPostNumbers(),
        [3],
        "only the style of the newly cloaked post is written"
      );

      this.evaluations.clear();
      this.moveInsideCloakingArea(post3, true);
      await waitFor(postSelector(post3, { cloaked: false }));
      await settled();

      assert.deepEqual(
        [...this.evaluations],
        [[post3, 1]],
        "only the uncloaked post is evaluated"
      );
      assert.deepEqual(
        this.styleMutatedPostNumbers(),
        [3],
        "only the style of the uncloaked post is written"
      );
      assert
        .dom(postSelector(post1, { cloaked: true }))
        .exists("post 1 is still cloaked");
      assert
        .dom(postSelector(post2, { cloaked: true }))
        .exists("post 2 is still cloaked");
    });

    test("uncloaks a post when cloaking is prevented for it", async function (assert) {
      const [post1, post2, , , post5] = this.posts;

      preventCloaking(post1.id);
      this.moveInsideCloakingArea(post5, true);
      await waitFor(postSelector(post1, { cloaked: false }));
      await settled();

      assert.deepEqual(
        [...this.evaluations],
        [[post1, 1]],
        "only the post with cloaking prevented is evaluated"
      );
      assert
        .dom(postSelector(post2, { cloaked: true }))
        .exists("post 2 is still cloaked");
    });
  }
);
