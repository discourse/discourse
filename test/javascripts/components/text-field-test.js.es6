moduleForComponent("text-field", {needs: []});

test("renders correctly with no properties set", function() {
  var component = this.subject();
  equal(component.get('type'), "text");
});

test("support a placeholder", function() {
  sandbox.stub(I18n, "t").returnsArg(0);

  var component = this.subject({
    placeholderKey: "placeholder.i18n.key"
  });

  equal(component.get('type'), "text");
  equal(component.get('placeholder'), "placeholder.i18n.key");
});
