import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BulkSelectTopicsDropdown from "discourse/components/bulk-select-topics-dropdown";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { TOPIC_VISIBILITY_REASONS } from "discourse/lib/constants";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const REGULAR_TOPIC_ID = 123;
const PM_TOPIC_ID = 124;
const UNLISTED_TOPIC_ID = 125;

function createBulkSelectHelper(testThis, opts = {}) {
  const store = getOwner(testThis).lookup("service:store");
  const regularTopic = store.createRecord("topic", {
    id: REGULAR_TOPIC_ID,
    visible: true,
  });
  const pmTopic = store.createRecord("topic", {
    id: PM_TOPIC_ID,
    visible: true,
    archetype: "private_message",
  });
  const unlistedTopic = store.createRecord("topic", {
    id: UNLISTED_TOPIC_ID,
    visibility_reason_id: TOPIC_VISIBILITY_REASONS.manually_unlisted,
    visible: false,
  });
  const topics = [regularTopic, pmTopic, unlistedTopic].filter((t) => {
    if (opts.topicIds) {
      return opts.topicIds.includes(t.id);
    } else {
      return true;
    }
  });

  const bulkSelectHelper = new BulkSelectHelper(testThis);
  topics.forEach((t) => {
    bulkSelectHelper.selected.addObject(t);
  });
  return bulkSelectHelper;
}

module("Integration | Component | BulkSelectTopicsDropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("actions all topics can perform", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item")
      .exists({ count: 7 });

    [
      "update-notifications",
      "reset-bump-dates",
      "close-topics",
      "append-tags",
      "replace-tags",
      "remove-tags",
      "delete-topics",
    ].forEach((action) => {
      assert
        .dom(`.fk-d-menu__inner-content .dropdown-menu__item .${action}`)
        .exists();
    });
  });

  test("does not allow unlisting topics that are already unlisted", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [UNLISTED_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .unlist-topics")
      .doesNotExist();
  });

  test("does not allow relisting topics that are already visible", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [REGULAR_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .relist-topics")
      .doesNotExist();
  });

  test("allows deferring topics if the user has the preference enabled", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.currentUser.user_option.enable_defer = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .defer")
      .exists();
  });

  test("does not allow tagging actions if tagging_enabled is false", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.siteSettings.tagging_enabled = false;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    ["append-tags", "replace-tags", "remove-tags"].forEach((action) => {
      assert
        .dom(`.fk-d-menu__inner-content .dropdown-menu__item .${action}`)
        .doesNotExist();
    });
  });

  test("does not allow tagging actions if user cannot manage topic", async function (assert) {
    const self = this;

    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    ["append-tags", "replace-tags", "remove-tags"].forEach((action) => {
      assert
        .dom(`.fk-d-menu__inner-content .dropdown-menu__item .${action}`)
        .doesNotExist();
    });
  });

  test("does not allow deleting topics if user is not staff", async function (assert) {
    const self = this;

    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .delete-topics")
      .doesNotExist();
  });

  test("does not allow unlisting or relisting PM topics", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [PM_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .relist-topics")
      .doesNotExist();
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .unlist-topics")
      .doesNotExist();
  });

  test("does not allow updating category for PMs", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [PM_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .update-category")
      .doesNotExist();
  });

  test("allows moving to archive and moving to inbox for PMs", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [PM_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{self.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .archive-messages")
      .exists();
    assert
      .dom(
        ".fk-d-menu__inner-content .dropdown-menu__item .move-messages-to-inbox"
      )
      .exists();
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .archive-topics")
      .doesNotExist();
  });
});
