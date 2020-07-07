import { mapRoutes } from "discourse/mapping-router";

moduleFor("controller:poll-ui-builder", "controller:poll-ui-builder", {
  setup() {
    this.registry.register("router:main", mapRoutes());
    this.subject().set("toolbarEvent", {
      getText: () => ""
    });
  },
  needs: ["controller:modal"]
});

test("isMultiple", function(assert) {
  const controller = this.subject();

  controller.setProperties({
    pollType: controller.multiplePollType,
    pollOptionsCount: 1
  });

  assert.equal(controller.isMultiple, true, "it should be true");

  controller.set("pollOptionsCount", 0);

  assert.equal(controller.isMultiple, false, "it should be false");

  controller.setProperties({ pollType: "random", pollOptionsCount: 1 });

  assert.equal(controller.isMultiple, false, "it should be false");
});

test("isNumber", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.set("pollType", controller.regularPollType);

  assert.equal(controller.isNumber, false, "it should be false");

  controller.set("pollType", controller.numberPollType);

  assert.equal(controller.isNumber, true, "it should be true");
});

test("showMinMax", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.set("pollType", controller.numberPollType);
  assert.equal(controller.showMinMax, true, "it should be true");

  controller.set("pollType", controller.multiplePollType);
  assert.equal(controller.showMinMax, true, "it should be true");

  controller.set("pollType", controller.regularPollType);
  assert.equal(controller.showMinMax, false, "it should be false");
});

test("pollOptionsCount", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.set("pollOptions", "1\n2\n");

  assert.equal(controller.pollOptionsCount, 2, "it should equal 2");

  controller.set("pollOptions", "");

  assert.equal(controller.pollOptionsCount, 0, "it should equal 0");
});

test("pollMinOptions", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.setProperties({
    pollType: controller.multiplePollType,
    pollOptionsCount: 1
  });

  assert.deepEqual(
    controller.pollMinOptions,
    [{ name: 1, value: 1 }],
    "it should return the right options"
  );

  controller.set("pollOptionsCount", 2);

  assert.deepEqual(
    controller.pollMinOptions,
    [
      { name: 1, value: 1 },
      { name: 2, value: 2 }
    ],
    "it should return the right options"
  );

  controller.set("pollType", controller.numberPollType);
  controller.siteSettings.poll_maximum_options = 2;

  assert.deepEqual(
    controller.pollMinOptions,
    [
      { name: 1, value: 1 },
      { name: 2, value: 2 }
    ],
    "it should return the right options"
  );
});

test("pollMaxOptions", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.setProperties({
    pollType: controller.multiplePollType,
    pollOptionsCount: 1,
    pollMin: 1
  });

  assert.deepEqual(
    controller.pollMaxOptions,
    [],
    "it should return the right options"
  );

  controller.set("pollOptionsCount", 2);

  assert.deepEqual(
    controller.pollMaxOptions,
    [{ name: 2, value: 2 }],
    "it should return the right options"
  );

  controller.siteSettings.poll_maximum_options = 3;
  controller.setProperties({
    pollType: controller.get("numberPollType"),
    pollStep: 2,
    pollMin: 1
  });

  assert.deepEqual(
    controller.pollMaxOptions,
    [
      { name: 2, value: 2 },
      { name: 3, value: 3 },
      { name: 4, value: 4 },
      { name: 5, value: 5 },
      { name: 6, value: 6 }
    ],
    "it should return the right options"
  );
});

test("pollStepOptions", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;
  controller.siteSettings.poll_maximum_options = 3;

  assert.equal(controller.pollStepOptions, null, "is should return null");

  controller.set("pollType", controller.numberPollType);

  assert.deepEqual(
    controller.pollStepOptions,
    [
      { name: 1, value: 1 },
      { name: 2, value: 2 },
      { name: 3, value: 3 }
    ],
    "it should return the right options"
  );
});

test("disableInsert", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  assert.equal(controller.disableInsert, true, "it should be true");

  controller.set("pollOptionsCount", 2);

  assert.equal(controller.disableInsert, false, "it should be false");

  controller.set("pollType", controller.numberPollType);

  assert.equal(controller.disableInsert, false, "it should be false");

  controller.setProperties({
    pollType: controller.regularPollType,
    pollOptionsCount: 3
  });

  assert.equal(controller.disableInsert, false, "it should be false");

  controller.setProperties({
    pollType: controller.regularPollType,
    pollOptionsCount: 0
  });

  assert.equal(controller.disableInsert, true, "it should be true");

  controller.setProperties({
    pollType: controller.regularPollType,
    pollOptionsCount: 1
  });

  assert.equal(controller.disableInsert, false, "it should be false");
});

test("number pollOutput", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;
  controller.siteSettings.poll_maximum_options = 20;

  controller.setProperties({
    pollType: controller.numberPollType,
    pollMin: 1
  });

  assert.equal(
    controller.pollOutput,
    "[poll type=number min=1 max=20 step=1]\n[/poll]\n",
    "it should return the right output"
  );

  controller.set("pollStep", 2);

  assert.equal(
    controller.pollOutput,
    "[poll type=number min=1 max=20 step=2]\n[/poll]\n",
    "it should return the right output"
  );

  controller.set("publicPoll", true);

  assert.equal(
    controller.pollOutput,
    "[poll type=number min=1 max=20 step=2 public=true]\n[/poll]\n",
    "it should return the right output"
  );

  controller.set("pollStep", 0);

  assert.equal(
    controller.pollOutput,
    "[poll type=number min=1 max=20 step=1 public=true]\n[/poll]\n",
    "it should return the right output"
  );
});

test("regular pollOutput", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;
  controller.siteSettings.poll_maximum_options = 20;

  controller.set("pollOptions", "1\n2");
  controller.setProperties({
    pollOptions: "1\n2",
    pollType: controller.regularPollType
  });

  assert.equal(
    controller.pollOutput,
    "[poll type=regular chartType=bar]\n* 1\n* 2\n[/poll]\n",
    "it should return the right output"
  );

  controller.set("publicPoll", "true");

  assert.equal(
    controller.pollOutput,
    "[poll type=regular public=true chartType=bar]\n* 1\n* 2\n[/poll]\n",
    "it should return the right output"
  );

  controller.set("pollGroups", "test");

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=regular public=true chartType=bar groups=test]\n* 1\n* 2\n[/poll]\n",
    "it should return the right output"
  );
});

test("multiple pollOutput", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;
  controller.siteSettings.poll_maximum_options = 20;

  controller.setProperties({
    isMultiple: true,
    pollType: controller.multiplePollType,
    pollMin: 1,
    pollOptions: "\n\n1\n\n2"
  });

  assert.equal(
    controller.pollOutput,
    "[poll type=multiple min=1 max=2 chartType=bar]\n* 1\n* 2\n[/poll]\n",
    "it should return the right output"
  );

  controller.set("publicPoll", "true");

  assert.equal(
    controller.pollOutput,
    "[poll type=multiple min=1 max=2 public=true chartType=bar]\n* 1\n* 2\n[/poll]\n",
    "it should return the right output"
  );
});

test("staff_only option is not present for non-staff", function(assert) {
  const controller = this.subject();
  controller.currentUser = { staff: false };

  assert.ok(
    controller.pollResults.filterBy("value", "staff_only").length === 0,
    "staff_only is not present"
  );
});

test("staff_only option is present for staff", function(assert) {
  const controller = this.subject();
  controller.currentUser = { staff: true };

  assert.ok(
    controller.pollResults.filterBy("value", "staff_only").length === 1,
    "staff_only is present"
  );
});
