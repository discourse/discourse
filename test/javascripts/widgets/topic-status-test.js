import { moduleForWidget, widgetTest } from "helpers/widget-test";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";

moduleForWidget("topic-status");

widgetTest("basics", {
  template: '{{mount-widget widget="topic-status" args=args}}',
  beforeEach(store) {
    this.set("args", {
      topic: store.createRecord("topic", { closed: true }),
      disableActions: true
    });
  },
  test(assert) {
    assert.ok(find(".topic-status .d-icon-lock").length);
  }
});

widgetTest("extendability", {
  template: '{{mount-widget widget="topic-status" args=args}}',
  beforeEach(store) {
    TopicStatusIcons.addObject([
      "has_accepted_answer",
      "far-check-square",
      "solved"
    ]);
    this.set("args", {
      topic: store.createRecord("topic", {
        has_accepted_answer: true
      }),
      disableActions: true
    });
  },
  test(assert) {
    assert.ok(find(".topic-status .d-icon-far-check-square").length);
  }
});
