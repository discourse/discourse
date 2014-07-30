moduleFor("controller:admin-badges", "controller:admin-badges", {
  needs: ['controller:modal', 'controller:admin-badge']
});

test("canEditDescription", function() {
  var badge = Discourse.Badge.create({id: 101, name: "Test Badge"});
  var controller = this.subject({ model: [badge] });
  controller.send('selectBadge', badge);
  ok(controller.get('canEditDescription'), "allows editing description when a translation exists for the badge name");

  badge.set('translatedDescription', 'translated');
  ok(!controller.get('canEditDescription'), "can't edit the description when it's got a translation");
});

test("createNewBadge", function() {
  var controller = this.subject();
  controller.send('createNewBadge');
  equal(controller.get('model.length'), 1, "adds a new badge to the list of badges");
});

test("selectBadge", function() {
  var badge = Discourse.Badge.create({id: 101, name: "Test Badge"}),
      controller = this.subject({ model: [badge] });

  controller.send('selectBadge', badge);
  equal(controller.get('selectedItem'), badge, "the badge is selected");
});

test("save", function() {
  var badge = Discourse.Badge.create({id: 101, name: "Test Badge"}),
      otherBadge = Discourse.Badge.create({id: 102, name: "Other Badge"}),
      controller = this.subject({ model: [badge, otherBadge] });

  controller.send('selectBadge', badge);
  sinon.stub(badge, "save").returns(Ember.RSVP.resolve({}));
  controller.send("save");
  ok(badge.save.calledOnce, "called save on the badge");
});

test("destroy", function() {
  var badge = Discourse.Badge.create({id: 101, name: "Test Badge"}),
      otherBadge = Discourse.Badge.create({id: 102, name: "Other Badge"}),
      controller = this.subject({model: [badge, otherBadge]});

  sinon.stub(badge, 'destroy').returns(Ember.RSVP.resolve({}));

  bootbox.confirm = function(text, yes, no, func) {
    func(false);
  };

  controller.send('selectBadge', badge);
  controller.send('destroy');
  ok(!badge.destroy.calledOnce, "badge is not destroyed if they user clicks no");

  bootbox.confirm = function(text, yes, no, func) {
    func(true);
  };

  controller.send('selectBadge', badge);
  controller.send('destroy');
  ok(badge.destroy.calledOnce, "badge is destroyed if they user clicks yes");
});
