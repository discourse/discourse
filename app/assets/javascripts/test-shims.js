// discourse-skip-module

define("sinon", () => {
  return { default: window.sinon };
});
define("qunit", () => {
  return {
    default: window.QUnit,
    test: window.QUnit.test,
    skip: window.QUnit.skip,
    module: window.QUnit.module,
  };
});
define("ember-qunit", () => {
  return {
    moduleFor: window.moduleFor,
    moduleForComponent: window.moduleForComponent,
  };
});
define("@ember/test-helpers", () => {
  return {
    setResolver: window.setResolver,
  };
});
define("pretender", () => {
  return { default: window.Pretender };
});
