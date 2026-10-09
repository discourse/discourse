import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BulkSelectTopicsDropdown from "discourse/components/bulk-select-topics-dropdown";
import BulkTopicActions from "discourse/components/modal/bulk-topic-actions";
import { addUniqueValueToArray } from "discourse/lib/array-tools";
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
    addUniqueValueToArray(bulkSelectHelper.selected, t);
  });
  return bulkSelectHelper;
}

module("Integration | Component | BulkSelectTopicsDropdown", function (hooks) {
  setupRenderingTest(hooks);

  test("actions all topics can perform", async function (assert) {
    this.currentUser.admin = true;
    this.site.set("can_tag_topics", true);
    this.currentUser.can_delete_all_posts_and_topics = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item")
      .exists({ count: 6 });

    [
      "update-notifications",
      "reset-bump-dates",
      "defer",
      "close-topics",
      "manage-tags",
      "delete-topics",
    ].forEach((action) => {
      assert
        .dom(`.fk-d-menu__inner-content .dropdown-menu__item .${action}`)
        .exists();
    });
  });

  test("does not allow unlisting topics that are already unlisted", async function (assert) {
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [UNLISTED_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .unlist-topics")
      .doesNotExist();
  });

  test("does not allow relisting topics that are already visible", async function (assert) {
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [REGULAR_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .relist-topics")
      .doesNotExist();
  });

  test("does not allow tagging actions if tagging_enabled is false", async function (assert) {
    this.currentUser.admin = true;
    this.siteSettings.tagging_enabled = false;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .manage-tags")
      .doesNotExist();
  });

  test("does not allow tagging actions if the user cannot tag topics", async function (assert) {
    this.currentUser.admin = true;
    this.site.set("can_tag_topics", false);
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .manage-tags")
      .doesNotExist();
  });

  test("does not allow tagging actions if user cannot manage topic", async function (assert) {
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .manage-tags")
      .doesNotExist();
  });

  test("does not allow deleting topics if the user cannot delete all posts and topics", async function (assert) {
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .delete-topics")
      .doesNotExist();
  });

  test("allows deleting topics for a non-staff user who can delete all posts and topics", async function (assert) {
    this.currentUser.can_delete_all_posts_and_topics = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .delete-topics")
      .exists();
  });

  test("does not allow unlisting or relisting PM topics", async function (assert) {
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [PM_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
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
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [PM_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .update-category")
      .doesNotExist();
  });

  test("allows moving to archive and moving to inbox for PMs", async function (assert) {
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this, {
      topicIds: [PM_TOPIC_ID],
    });

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
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

  test("supports excluding built-in buttons and handling custom actions", async function (assert) {
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);
    this.extraButtons = [
      {
        id: "custom-action",
        icon: "trash-can",
        name: "Custom Action",
        visible: () => true,
      },
    ];
    this.excludedButtonIds = ["delete-topics"];
    this.onAction = (actionId) => assert.step(actionId);

    await render(
      <template>
        <BulkSelectTopicsDropdown
          @bulkSelectHelper={{this.bulkSelectHelper}}
          @excludedButtonIds={{this.excludedButtonIds}}
          @extraButtons={{this.extraButtons}}
          @onAction={{this.onAction}}
        />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .delete-topics")
      .doesNotExist();
    await click(
      ".fk-d-menu__inner-content .dropdown-menu__item .custom-action"
    );
    assert.verifySteps(["custom-action"]);
  });

  test("an extra button reusing a built-in id overrides the label, not the action", async function (assert) {
    this.currentUser.admin = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);
    this.extraButtons = [
      {
        id: "delete-topics",
        icon: "trash-can",
        name: "Delete Topics (override)",
        visible: () => true,
      },
    ];
    this.excludedButtonIds = ["delete-topics"];

    await render(
      <template>
        <BulkSelectTopicsDropdown
          @bulkSelectHelper={{this.bulkSelectHelper}}
          @excludedButtonIds={{this.excludedButtonIds}}
          @extraButtons={{this.extraButtons}}
        />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    assert
      .dom(".fk-d-menu__inner-content .dropdown-menu__item .delete-topics")
      .hasTextContaining("Delete Topics (override)");

    await click(
      ".fk-d-menu__inner-content .dropdown-menu__item .delete-topics"
    );
    assert.strictEqual(
      getOwner(this).lookup("service:modal").activeModal.component,
      BulkTopicActions,
      "the built-in delete action still runs"
    );
  });

  test("the delete description does not claim the deletion is permanent", async function (assert) {
    this.currentUser.admin = true;
    this.currentUser.can_delete_all_posts_and_topics = true;
    this.bulkSelectHelper = createBulkSelectHelper(this);

    await render(
      <template>
        <BulkSelectTopicsDropdown @bulkSelectHelper={{this.bulkSelectHelper}} />
      </template>
    );

    await click(".bulk-select-topics-dropdown-trigger");
    await click(
      ".fk-d-menu__inner-content .dropdown-menu__item .delete-topics"
    );

    const { description } =
      getOwner(this).lookup("service:modal").activeModal.opts.model;

    assert.strictEqual(typeof description, "string", "a description is shown");
    assert.false(
      /permanent|cannot be undone/i.test(description),
      `bulk delete is recoverable, but the copy reads "${description}"`
    );
  });
});
