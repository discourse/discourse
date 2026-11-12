import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostMetaDataDate from "discourse/components/post/meta-data/date";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

function renderComponent(post) {
  return render(<template><PostMetaDataDate @post={{post}} /></template>);
}

module("Integration | Component | Post | PostMetaDataDate", function (hooks) {
  setupRenderingTest(hooks);

  let clock;

  hooks.beforeEach(function () {
    clock = fakeTime("2026-07-13T12:00:00", null, true);

    this.store = getOwner(this).lookup("service:store");
    const topic = this.store.createRecord("topic", { id: 1 });
    this.post = this.store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
    });
  });

  hooks.afterEach(function () {
    clock?.restore();
  });

  test("announces recent posts with a relative label instead of the full date and time", async function (assert) {
    this.post.created_at = moment().subtract(20, "minutes").toISOString();

    await renderComponent(this.post);

    assert.dom("a.post-date").hasAria("label", "20 mins ago");

    assert
      .dom("a.post-date > span[aria-hidden=true] .relative-date")
      .exists("the relative date and its tooltip are accessibility-hidden");
  });

  test("refreshes the label as time passes", async function (assert) {
    this.post.created_at = moment().subtract(2, "days").toISOString();

    await renderComponent(this.post);

    assert.dom("a.post-date").hasAria("label", "2 days ago");

    clock.tick(24 * 60 * 60 * 1000);
    getOwner(this).lookup("service:a11y").autoUpdatingRelativeDateRef =
      new Date();
    await settled();

    assert.dom("a.post-date").hasAria("label", "3 days ago");
  });

  test("announces older posts with a short absolute date", async function (assert) {
    this.post.created_at = moment().subtract(31, "days").toISOString();

    await renderComponent(this.post);

    assert.dom("a.post-date").hasAria("label", "Jun 12");
  });

  test("includes the year for posts from previous years", async function (assert) {
    this.post.created_at = moment().subtract(1, "year").toISOString();

    await renderComponent(this.post);

    assert.dom("a.post-date").hasAria("label", "Jul 13, 2025");
  });
});
