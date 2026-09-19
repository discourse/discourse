import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import SidebarNewTopicButton from "../../discourse/components/sidebar-new-topic-button";

module(
  "Horizon | Integration | Component | SidebarNewTopicButton",
  function (hooks) {
    // stubRouter supplies the currentRoute the button reads to pre-fill a category or tag.
    setupRenderingTest(hooks, { stubRouter: true });

    hooks.beforeEach(function () {
      // Both of these gate rendering on their own, so without them the negative assertion below
      // would pass no matter what the panel is. `sidebarEnabled` is a getter and has to be
      // stubbed rather than set.
      sinon
        .stub(this.owner.lookup("controller:application"), "sidebarEnabled")
        .get(() => true);
      this.currentUser.set("can_create_topic", true);

      // A plain forum path. The panel, not the path, is what should decide this, so the
      // assertions below have to hold on a URL that looks like ordinary browsing.
      this.owner.lookup("service:router").currentURL = "/latest";
    });

    test("renders while the forum panel owns the sidebar", async function (assert) {
      this.owner.lookup("service:sidebar-state").setPanel(MAIN_PANEL);

      await render(<template><SidebarNewTopicButton /></template>);

      assert.dom(".sidebar-new-topic-button__wrapper").exists();
    });

    // Rendering happens without a URL, so nothing here can be hidden by matching a path. Admin
    // stands in for every takeover, which all claim the sidebar the same way.
    test("is hidden while another panel owns the sidebar", async function (assert) {
      this.owner.lookup("service:sidebar-state").setPanel(ADMIN_PANEL);

      await render(<template><SidebarNewTopicButton /></template>);

      assert.dom(".sidebar-new-topic-button__wrapper").doesNotExist();
    });
  }
);
