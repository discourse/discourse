import componentTest from "helpers/component-test";

export function moduleForWidget(name, options = {}) {
  moduleForComponent(
    name,
    `widget:${name}`,
    Object.assign(
      { integration: true },
      { beforeEach: options.beforeEach, afterEach: options.afterEach }
    )
  );
}

export function widgetTest(name, opts) {
  return componentTest(name, opts);
}
