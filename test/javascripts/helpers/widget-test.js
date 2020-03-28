import componentTest from "helpers/component-test";
const { getProperties } = Ember;

export function moduleForWidget(name, options = {}) {
  moduleForComponent(
    name,
    `widget:${name}`,
    Object.assign(
      { integration: true },
      getProperties(options, ["beforeEach", "afterEach"])
    )
  );
}

export function widgetTest(name, opts) {
  return componentTest(name, opts);
}
