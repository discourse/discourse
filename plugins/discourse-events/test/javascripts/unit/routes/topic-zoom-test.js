import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

// The sidebar is hidden on this page by core's {{hideApplicationSidebar}}
// helper in templates/topic-zoom.gjs, which is core's to test and out of this
// route's reach. The route's own jobs are closing the chat it replaces and
// releasing the topic it borrowed from the topic controller.

module("Unit | Route | topic-zoom", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);

    this.topicController = {
      set(field, value) {
        this[field] = value;
      },
    };

    this.closeChatVisibility = sinon.spy();
    owner.unregister("service:embeddable-chat");
    owner.register(
      "service:embeddable-chat",
      { closeChatVisibility: this.closeChatVisibility },
      { instantiate: false }
    );

    this.subject = owner.lookup("route:topic-zoom");
    // The route hands its topic controller to the app; only the values it sets
    // on it are under test.
    this.subject.controllerFor = () => this.topicController;
  });

  test("closes the embeddable chat on activation", function (assert) {
    this.subject.activate();

    assert.true(
      this.closeChatVisibility.called,
      "the meeting takes over the chat on the way in"
    );
  });

  test("clears the shared topic model on exit", function (assert) {
    this.subject.activate();
    this.subject.deactivate();

    assert.strictEqual(
      this.topicController.model,
      null,
      "the topic is released so it does not leak into the next page"
    );
  });
});
