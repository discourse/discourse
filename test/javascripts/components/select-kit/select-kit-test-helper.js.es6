import selectKit from "helpers/select-kit-helper";

export function testSelectKitModule(moduleName, options = {}) {
  moduleForComponent(`select-kit/${moduleName}`, {
    integration: true,

    beforeEach() {
      this.set("subject", selectKit());
      options.beforeEach && options.beforeEach.call(this);
    },

    afterEach() {
      options.afterEach && options.afterEach.call(this);
    }
  });
}

export const DEFAULT_CONTENT = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" }
];

export function setDefaultState(ctx, value, options = {}) {
  const properties = Object.assign(
    {
      onChange: v => {
        this.set("value", v);
      }
    },
    options || {}
  );

  ctx.setProperties(properties);
}
