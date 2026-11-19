import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  SCROLLED_DOWN,
  SCROLLED_UP,
} from "discourse/services/scroll-direction";

module("Unit | Service | header", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.header = getOwner(this).lookup("service:header");
  });

  test("follows the on-page topic title in both scroll directions with mobile footer navigation", function (assert) {
    const mobileTabBar = this.owner.lookup("service:mobile-tab-bar");
    const scrollDirection = this.owner.lookup("service:scroll-direction");
    const site = this.owner.lookup("service:site");
    const enabled = sinon.stub(mobileTabBar, "enabled").get(() => true);
    const mobileView = sinon.stub(site, "mobileView").get(() => true);

    try {
      this.header.enterTopic({}, false);
      scrollDirection.lastScrollDirection = SCROLLED_DOWN;
      assert.true(
        this.header.topicInfoVisible,
        "shows the title on scroll down"
      );

      this.header.mainTopicTitleVisible = true;
      assert.true(
        this.header.topicInfoVisible,
        "keeps the header stable if the on-page title briefly re-enters on scroll down"
      );

      scrollDirection.lastScrollDirection = SCROLLED_UP;
      assert.false(
        this.header.topicInfoVisible,
        "releases the latch when scrolling back toward the on-page title"
      );

      this.header.mainTopicTitleVisible = false;
      assert.true(this.header.topicInfoVisible, "keeps the title on scroll up");

      this.header.mainTopicTitleVisible = true;
      assert.false(
        this.header.topicInfoVisible,
        "hides the duplicate title on scroll up"
      );
    } finally {
      mobileView.restore();
      enabled.restore();
    }
  });

  test("it registers hiders", function (assert) {
    this.header.registerHider(this, ["search", "login"]);
    assert.true(this.header.headerButtonsHidden.includes("search"));
    assert.true(this.header.headerButtonsHidden.includes("login"));
  });

  test("it does not register invalid buttons for hiders", function (assert) {
    const stub = sinon.stub(console, "error");
    this.header.registerHider(this, ["search", "blahblah"]);

    assert.false(this.header.headerButtonsHidden.includes("blah"));
    assert.true(
      stub.calledWith(
        "Invalid button to hide: blahblah, valid buttons are: search, login, signup, menu"
      )
    );
    stub.restore();
  });
});
