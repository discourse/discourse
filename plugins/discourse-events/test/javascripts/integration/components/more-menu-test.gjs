import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import MoreMenu from "../../discourse/components/discourse-post-event/more-menu";

module("Integration | Component | MoreMenu", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");

    this.user = store.createRecord("user", {
      username: "j.jaffeux",
      name: "joffrey",
      id: 321,
    });

    getOwner(this).unregister("service:current-user");
    getOwner(this).register("service:current-user", this.user, {
      instantiate: false,
    });
  });

  test("value transformer works", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "discourse-calendar-event-more-menu-should-show-participants",
        () => {
          return true; // by default it should show to canActOnDiscoursePostEvent users
        }
      );
    });

    const store = getOwner(this).lookup("service:store");
    const creator = store.createRecord("user", {
      username: "gabriel",
      name: "gabriel",
      id: 322,
    });

    await render(
      <template>
        <MoreMenu
          @event={{hash
            isExpired=false
            creator=creator
            canActOnDiscoursePostEvent=false
          }}
        />
      </template>
    );

    await click(".discourse-post-event-more-menu-trigger");
    assert.dom(".show-all-participants").exists();
  });

  test("offers editors the recording once a livestream has ended", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const creator = store.createRecord("user", {
      username: "gabriel",
      id: 322,
    });
    const event = {
      isExpired: true,
      livestream: true,
      creator,
      canActOnDiscoursePostEvent: true,
    };

    await render(<template><MoreMenu @event={{event}} /></template>);
    await click(".discourse-post-event-more-menu-trigger");

    assert.dom(".manage-recording").hasText("Add recording link");
  });

  test("does not offer the recording before a livestream ends", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const creator = store.createRecord("user", {
      username: "gabriel",
      id: 322,
    });
    const event = {
      isExpired: false,
      livestream: true,
      creator,
      canActOnDiscoursePostEvent: true,
    };

    await render(<template><MoreMenu @event={{event}} /></template>);
    await click(".discourse-post-event-more-menu-trigger");

    assert.dom(".manage-recording").doesNotExist();
  });

  test("renders nothing when there is nothing to offer", async function (assert) {
    getOwner(this).unregister("service:current-user");
    const event = { isExpired: true, creator: { username: "gabriel" } };

    await render(<template><MoreMenu @event={{event}} /></template>);

    assert.dom(".discourse-post-event-more-menu-trigger").doesNotExist();
  });

  test("offers the participants only once there are some", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const creator = store.createRecord("user", {
      username: "gabriel",
      id: 322,
    });
    const event = {
      isExpired: false,
      creator,
      canActOnDiscoursePostEvent: true,
      stats: { invited: 0 },
    };

    await render(<template><MoreMenu @event={{event}} /></template>);
    await click(".discourse-post-event-more-menu-trigger");

    assert.dom(".show-all-participants").doesNotExist();
  });
});
