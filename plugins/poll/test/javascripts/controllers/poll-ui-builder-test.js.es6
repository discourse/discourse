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
    pollType: controller.get("multiplePollType"),
    pollOptionsCount: 1
  });

  assert.equal(controller.get("isMultiple"), true, "it should be true");

  controller.set("pollOptionsCount", 0);

  assert.equal(controller.get("isMultiple"), false, "it should be false");

  controller.setProperties({ pollType: "random", pollOptionsCount: 1 });

  assert.equal(controller.get("isMultiple"), false, "it should be false");
});

test("isNumber", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.set("pollType", "random");

  assert.equal(controller.get("isNumber"), false, "it should be false");

  controller.set("pollType", controller.get("numberPollType"));

  assert.equal(controller.get("isNumber"), true, "it should be true");
});

test("showMinMax", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.setProperties({
    isNumber: true,
    isMultiple: false
  });

  assert.equal(controller.get("showMinMax"), true, "it should be true");

  controller.setProperties({
    isNumber: false,
    isMultiple: true
  });

  assert.equal(controller.get("showMinMax"), true, "it should be true");

  controller.setProperties({
    isNumber: false,
    isMultiple: false,
    isRegular: true
  });

  assert.equal(controller.get("showMinMax"), false, "it should be false");
});

test("pollOptionsCount", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.set("pollOptions", "1\n2\n");

  assert.equal(controller.get("pollOptionsCount"), 2, "it should equal 2");

  controller.set("pollOptions", "");

  assert.equal(controller.get("pollOptionsCount"), 0, "it should equal 0");
});

test("pollMinOptions", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.setProperties({
    isMultiple: true,
    pollOptionsCount: 1
  });

  assert.deepEqual(
    controller.get("pollMinOptions"),
    [{ name: 1, value: 1 }],
    "it should return the right options"
  );

  controller.set("pollOptionsCount", 2);

  assert.deepEqual(
    controller.get("pollMinOptions"),
    [{ name: 1, value: 1 }, { name: 2, value: 2 }],
    "it should return the right options"
  );

  controller.set("isNumber", true);
  controller.siteSettings.poll_maximum_options = 2;

  assert.deepEqual(
    controller.get("pollMinOptions"),
    [{ name: 1, value: 1 }, { name: 2, value: 2 }],
    "it should return the right options"
  );
});

test("pollMaxOptions", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.setProperties({
    isMultiple: true,
    pollOptionsCount: 1,
    pollMin: 1
  });

  assert.deepEqual(
    controller.get("pollMaxOptions"),
    [],
    "it should return the right options"
  );

  controller.set("pollOptionsCount", 2);

  assert.deepEqual(
    controller.get("pollMaxOptions"),
    [{ name: 2, value: 2 }],
    "it should return the right options"
  );

  controller.siteSettings.poll_maximum_options = 3;
  controller.setProperties({
    isMultiple: false,
    isNumber: true,
    pollStep: 2,
    pollMin: 1
  });

  assert.deepEqual(
    controller.get("pollMaxOptions"),
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

  controller.set("isNumber", false);

  assert.equal(
    controller.get("pollStepOptions"),
    null,
    "is should return null"
  );

  controller.setProperties({ isNumber: true });

  assert.deepEqual(
    controller.get("pollStepOptions"),
    [{ name: 1, value: 1 }, { name: 2, value: 2 }, { name: 3, value: 3 }],
    "it should return the right options"
  );
});

test("disableInsert", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;

  controller.setProperties({ isRegular: true });

  assert.equal(controller.get("disableInsert"), true, "it should be true");

  controller.setProperties({ isRegular: true, pollOptionsCount: 2 });

  assert.equal(controller.get("disableInsert"), false, "it should be false");

  controller.setProperties({ isNumber: true });

  assert.equal(controller.get("disableInsert"), false, "it should be false");

  controller.setProperties({ isNumber: false, pollOptionsCount: 3 });

  assert.equal(controller.get("disableInsert"), false, "it should be false");

  controller.setProperties({ isNumber: false, pollOptionsCount: 1 });

  assert.equal(controller.get("disableInsert"), true, "it should be true");
});

test("number pollOutput", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;
  controller.siteSettings.poll_maximum_options = 20;

  controller.setProperties({
    isNumber: true,
    pollType: controller.get("numberPollType"),
    pollMin: 1
  });

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=number min=1 max=20 step=1]\n[/poll]",
    "it should return the right output"
  );

  controller.set("pollStep", 2);

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=number min=1 max=20 step=2]\n[/poll]",
    "it should return the right output"
  );

  controller.set("publicPoll", true);

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=number min=1 max=20 step=2 public=true]\n[/poll]",
    "it should return the right output"
  );

  controller.set("pollStep", 0);

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=number min=1 max=20 step=1 public=true]\n[/poll]",
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
    pollType: controller.get("regularPollType")
  });

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=regular]\n* 1\n* 2\n[/poll]",
    "it should return the right output"
  );

  controller.set("publicPoll", "true");

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=regular public=true]\n* 1\n* 2\n[/poll]",
    "it should return the right output"
  );
});

test("multiple pollOutput", function(assert) {
  const controller = this.subject();
  controller.siteSettings = Discourse.SiteSettings;
  controller.siteSettings.poll_maximum_options = 20;

  controller.setProperties({
    isMultiple: true,
    pollType: controller.get("multiplePollType"),
    pollMin: 1,
    pollOptions: "\n\n1\n\n2"
  });

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=multiple min=1 max=2]\n* 1\n* 2\n[/poll]",
    "it should return the right output"
  );

  controller.set("publicPoll", "true");

  assert.equal(
    controller.get("pollOutput"),
    "[poll type=multiple min=1 max=2 public=true]\n* 1\n* 2\n[/poll]",
    "it should return the right output"
  );
});
