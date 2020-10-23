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
let _app;
define("@ember/test-helpers", () => {
  return {
    setResolver: window.setResolver,
    setApplication(app) {
      _app = app;
    },
    getApplication() {
      return _app;
    },
    visit() {
      return window.visit(...arguments);
    },
    currentURL() {
      return window.currentURL(...arguments);
    },
  };
});
define("pretender", () => {
  return { default: window.Pretender };
});
