import componentTest from 'helpers/component-test';

export function moduleForWidget(name) {
  moduleForComponent(name, `widget:${name}`, { integration: true });
}

export function widgetTest(name, opts) {
  return componentTest(name, opts);
}
