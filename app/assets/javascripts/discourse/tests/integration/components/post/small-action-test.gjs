import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostSmallAction from "discourse/components/post/small-action";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

function renderComponent(post) {
  return render(<template><PostSmallAction @post={{post}} /></template>);
}

module("Integration | Component | Post | PostSmallAction", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.glimmer_post_stream_mode = "enabled";

    const store = getOwner(this).lookup("service:store");
    const topic = store.createRecord("topic", { id: 1 });
    const post = store.createRecord("post", {
      id: 123,
      post_number: 1,
      topic,
      like_count: 3,
      action_code: "open_topic",
      actions_summary: [{ id: 2, count: 1, hidden: false, can_act: true }],
    });

    this.post = post;
  });

  test("does not have delete/edit/recover buttons by default", async function (assert) {
    await renderComponent(this.post);

    assert.dom(".small-action-desc .small-action-delete").doesNotExist();
    assert.dom(".small-action-desc .small-action-recover").doesNotExist();
    assert.dom(".small-action-desc .small-action-edit").doesNotExist();
  });

  test("shows edit button if canEdit", async function (assert) {
    this.post.can_edit = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-edit")
      .exists("adds the edit small action button");
  });

  test("can add classes to the component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("post-small-action-class", ({ value }) => {
        value.push("custom-class");
        return value;
      });

      api.addPostSmallActionClassesCallback(
        (post) => `api-custom-class-${post.id}`
      );
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action.custom-class.api-custom-class-123")
      .exists("applies the custom classes to the component");
  });

  test("can use a custom component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("post-small-action-custom-component", () => {
        return <template>
          <div class="custom-component">CUSTOM COMPONENT</div>
        </template>;
      });
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action .custom-component")
      .exists("uses the custom component");
    assert
      .dom(".small-action .small-action-custom-message")
      .doesNotExist("won't render the cooked test");
  });

  test("can customize the icon of the component", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-small-action-icon",
        () => "far-circle-check"
      );
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action .d-icon-far-circle-check")
      .exists("the custom icon was rendered");
  });

  test("api.addGroupPostSmallActionCode", async function (assert) {
    withPluginApi((api) => {
      api.addGroupPostSmallActionCode("some_code");
    });

    this.post.action_code = "some_code";
    this.post.action_code_who = "somegroup";

    I18n.translations[I18n.locale].js.action_codes = {
      some_code: "Some %{who} Code Action",
    };

    await renderComponent(this.post);

    assert
      .dom(".small-action")
      .hasText(
        "Some @somegroup Code Action",
        "the action code text was rendered correctly"
      );

    assert
      .dom("a.mention-group")
      .hasAttribute(
        "href",
        "/g/somegroup",
        "the group mention link has the correct href"
      );
  });

  test("api.addPostSmallActionIcon", async function (assert) {
    withPluginApi((api) => {
      api.addPostSmallActionIcon("open_topic", "far-circle-check");
      api.addPostSmallActionIcon("private_topic", "heart");
    });

    await renderComponent(this.post);

    assert
      .dom(".small-action .d-icon-far-circle-check")
      .exists("the correct custom icon was rendered");
  });

  test("does not show edit button if canRecover even if canEdit", async function (assert) {
    this.post.can_edit = true;
    this.post.deleted_at = new Date().toISOString();
    this.post.can_recover = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-edit")
      .doesNotExist("does not add the edit small action button");
    assert
      .dom(".small-action-desc .small-action-recover")
      .exists("adds the recover small action button");
  });

  test("shows delete button if canDelete", async function (assert) {
    this.post.can_delete = true;
    this.currentUser.staff = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-delete")
      .exists("adds the delete small action button");
  });

  test("shows undo button if canRecover", async function (assert) {
    this.post.deleted_at = new Date().toISOString();
    this.post.can_recover = true;

    await renderComponent(this.post);

    assert
      .dom(".small-action-desc .small-action-recover")
      .exists("adds the recover small action button");
  });
});
