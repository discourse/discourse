import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableRefreshItem from "discourse/components/reviewable-refresh/item";
import Reviewable from "discourse/models/reviewable";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ReviewableRefresh | Item ", function (hooks) {
  setupRenderingTest(hooks);

  test("has right CSS class based on reviewable type", async function (assert) {
    const reviewable = Reviewable.create({
      type: "post",
    });

    this.siteSettings.blur_tl0_flagged_posts_media = true;

    await render(
      <template><ReviewableRefreshItem @reviewable={{reviewable}} /></template>
    );

    assert.dom(".review-item").hasClass("post");
  });

  test("has `reviewable-stale` class when last performing username is present for reviewable", async function (assert) {
    const reviewable = Reviewable.create({
      type: "post",
      last_performing_username: "user123",
    });

    await render(
      <template><ReviewableRefreshItem @reviewable={{reviewable}} /></template>
    );

    assert.dom(".review-item").hasClass("reviewable-stale");
  });

  test("has `blur-images` class when blur_tl0_flagged_posts_media is enabled and reviewable's `target_created_by_trust_level` is 0", async function (assert) {
    const reviewable = Reviewable.create({
      type: "post",
      target_created_by_trust_level: 0,
    });

    this.siteSettings.blur_tl0_flagged_posts_media = true;

    await render(
      <template><ReviewableRefreshItem @reviewable={{reviewable}} /></template>
    );

    assert.dom(".review-item").hasClass("blur-images");
  });
});
