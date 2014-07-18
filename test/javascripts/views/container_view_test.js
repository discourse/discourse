var SomeViewClass = Ember.View.extend(),
    containerView;

function containerHasOnlyOneChild(klass) {
  equal(containerView.get('childViews').length, 1, "container has no other children than the one created by method");
  ok(containerView.objectAt(0) instanceof klass, "container's child created by method is an instance of a correct class");
}

function containerHasTwoChildren(klass1, klass2) {
  equal(containerView.get('childViews').length, 2, "container has both already existing and newly created children");
  ok(containerView.objectAt(0) instanceof klass1, "already existing child's class is correct");
  ok(containerView.objectAt(1) instanceof klass2, "newly created child's class is correct");
}

var childHasProperty = function(name) {
  equal(containerView.objectAt(0).get(name), name, "method passes properties to the container's child it creates");
};

module("view:container", {
  setup: function() {
    containerView = Discourse.__container__.lookup('view:container');
  }
});

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(containerView));
});

test("attachViewWithArgs: creates a view of a given class with given properties and appends it to the container", function() {
  containerView.attachViewWithArgs({foo: "foo"}, SomeViewClass);

  containerHasOnlyOneChild(SomeViewClass);
  childHasProperty("foo");
});

test("attachViewWithArgs: creates a view of a given class without any properties and appends it to the container", function() {
  containerView.attachViewWithArgs(null, SomeViewClass);

  containerHasOnlyOneChild(SomeViewClass);
});

test("attachViewWithArgs: creates a view without class specified (Ember.View is used by default) with given properties and appends it to the container", function() {
  containerView.attachViewWithArgs({foo: "foo"});

  containerHasOnlyOneChild(Ember.View);
  childHasProperty("foo");
});

test("attachViewWithArgs: creates a view without class specified (Ember.View is used by default) without any properties and appends it to the container", function() {
  containerView.attachViewWithArgs();

  containerHasOnlyOneChild(Ember.View);
});

test("attachViewWithArgs: appends a view to a container already containing other views", function() {
  var AlreadyContainedViewClass = Ember.View.extend();
  var alreadyContainedView = AlreadyContainedViewClass.create();
  containerView.pushObject(alreadyContainedView);

  containerView.attachViewWithArgs(null, SomeViewClass);

  containerHasTwoChildren(AlreadyContainedViewClass, SomeViewClass);
});

test("attachViewClass: creates a view of a given class without any properties and appends it to the container", function() {
  containerView.attachViewClass(SomeViewClass);

  containerHasOnlyOneChild(SomeViewClass);
});

test("attachViewClass: creates a view without class specified (Ember.View is used by default) without any properties and appends it to the container", function() {
  containerView.attachViewClass();

  containerHasOnlyOneChild(Ember.View);
});

test("attachViewClass: appends a view to a container already containing other views", function() {
  var AlreadyContainedViewClass = Ember.View.extend();
  var alreadyContainedView = AlreadyContainedViewClass.create();
  containerView.pushObject(alreadyContainedView);

  containerView.attachViewClass(SomeViewClass);

  containerHasTwoChildren(AlreadyContainedViewClass, SomeViewClass);
});
