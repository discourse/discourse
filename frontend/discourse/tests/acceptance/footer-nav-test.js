import { click, find, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Footer navigation on iPad", function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({ mobile_footer_navigation: false });

  test("opens slide-in menus below the navigation bar", async function (assert) {
    const capabilities = this.owner.lookup("service:capabilities");
    sinon.stub(capabilities, "isAppWebview").value(true);
    sinon.stub(capabilities, "isIpadOS").value(true);

    await visit("/");
    await click(".d-header-icons .current-user button");

    assert.dom(document.documentElement).hasClass("footer-nav-ipad");
    const barHeight = find(".footer-nav").offsetHeight;

    assert.dom(".user-menu.menu-panel.slide-in").hasStyle({
      top: `${barHeight}px`,
      height: `${window.innerHeight - barHeight}px`,
    });
  });
});
