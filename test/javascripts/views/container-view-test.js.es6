var SomeViewClass = Ember.View.extend();

function containerHasOnlyOneChild(containerView, klass) {
  equal(containerView.get('childViews').length, 1, "container has no other children than the one created by method");
  ok(containerView.objectAt(0) instanceof klass, "container's child created by method is an instance of a correct class");
}

function containerHasTwoChildren(containerView, klass1, klass2) {
  equal(containerView.get('childViews').length, 2, "container has both already existing and newly created children");
  ok(containerView.objectAt(0) instanceof klass1, "already existing child's class is correct");
  ok(containerView.objectAt(1) instanceof klass2, "newly created child's class is correct");
}

function childHasProperty(containerView, name) {
  equal(containerView.objectAt(0).get(name), name, "method passes properties to the container's child it creates");
}

moduleFor("view:container");

test("attachViewWithArgs: creates a view of a given class with given properties and appends it to the container", function() {
  var containerView = this.subject();
  containerView.attachViewWithArgs({foo: "foo"}, SomeViewClass);
  containerHasOnlyOneChild(containerView, SomeViewClass);
  childHasProperty(containerView, "foo");
});

test("attachViewWithArgs: creates a view of a given class without any properties and appends it to the container", function() {

  var containerView = this.subject();
  containerView.attachViewWithArgs(null, SomeViewClass);
  containerHasOnlyOneChild(containerView, SomeViewClass);
});

test("attachViewWithArgs: creates a view without class specified (Ember.View is used by default) with given properties and appends it to the container", function() {
  var containerView = this.subject();
  containerView.attachViewWithArgs({foo: "foo"});

  containerHasOnlyOneChild(containerView, Ember.View);
  childHasProperty(containerView, "foo");
});

test("attachViewWithArgs: creates a view without class specified (Ember.View is used by default) without any properties and appends it to the container", function() {
  var containerView = this.subject();
  containerView.attachViewWithArgs();

  containerHasOnlyOneChild(containerView, Ember.View);
});

test("attachViewWithArgs: appends a view to a container already containing other views", function() {
  var AlreadyContainedViewClass = Ember.View.extend();
  var alreadyContainedView = AlreadyContainedViewClass.create();
  var containerView = this.subject();
  containerView.pushObject(alreadyContainedView);

  containerView.attachViewWithArgs(null, SomeViewClass);

  containerHasTwoChildren(containerView, AlreadyContainedViewClass, SomeViewClass);
});

test("attachViewClass: creates a view of a given class without any properties and appends it to the container", function() {
  var containerView = this.subject();
  containerView.attachViewClass(SomeViewClass);

  containerHasOnlyOneChild(containerView, SomeViewClass);
});

test("attachViewClass: creates a view without class specified (Ember.View is used by default) without any properties and appends it to the container", function() {
  var containerView = this.subject();
  containerView.attachViewClass();

  containerHasOnlyOneChild(containerView, Ember.View);
});

test("attachViewClass: appends a view to a container already containing other views", function() {
  var AlreadyContainedViewClass = Ember.View.extend();
  var alreadyContainedView = AlreadyContainedViewClass.create();
  var containerView = this.subject();
  containerView.pushObject(alreadyContainedView);

  containerView.attachViewClass(SomeViewClass);

  containerHasTwoChildren(containerView, AlreadyContainedViewClass, SomeViewClass);
});
