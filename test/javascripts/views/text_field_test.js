var appendTextFieldWithProperties = function(properties) {
  var view = viewClassFor('text-field').create(properties);
  Ember.run(function() {
    view.appendTo(fixture());
  });
};

var hasAttr = function($element, attrName, attrValue) {
  equal($element.attr(attrName), attrValue, "'" + attrName + "' attribute is correctly rendered");
};

var hasNoAttr = function($element, attrName) {
  equal($element.attr(attrName), undefined, "'" + attrName + "' attribute is not rendered");
};

module("view:text-field");

test("renders correctly with no properties set", function() {
  appendTextFieldWithProperties({});

  var $input = fixture("input");
  hasAttr($input, "type", "text");
  hasAttr($input, "placeholder", "");
  hasNoAttr($input, "autocorrect");
  hasNoAttr($input, "autocapitalize");
  hasNoAttr($input, "autofocus");
});

test("renders correctly with all allowed properties set", function() {
  this.stub(I18n, "t").returnsArg(0);

  appendTextFieldWithProperties({
    autocorrect: "on",
    autocapitalize: "off",
    autofocus: "autofocus",
    placeholderKey: "placeholder.i18n.key"
  });

  var $input = fixture("input");
  hasAttr($input, "type", "text");
  hasAttr($input, "placeholder", "placeholder.i18n.key");
  hasAttr($input, "autocorrect", "on");
  hasAttr($input, "autocapitalize", "off");
  hasAttr($input, "autofocus", "autofocus");
});

test("is registered as helper", function() {
  var view = Ember.View.create({
    template: Ember.Handlebars.compile("{{text-field}}")
  });

  Ember.run(function() {
    view.appendTo(fixture());
  });

  ok(exists(fixture("input")));
});
