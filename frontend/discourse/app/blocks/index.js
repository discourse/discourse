// This secret symbol allows us to identify block components. We use this to ensure
// only block components can be rendered inside BlockOutlets, and that block components
// cannot be rendered in another context.
export const _BLOCK_IDENTIFIER = Symbol("block secret");

/**
 * Mark a component class as a Block component.
 */
export function block(name) {
  return function (target) {
    return class extends target {
      static blockName = name;
      static [_BLOCK_IDENTIFIER] = true;

      constructor() {
        super(...arguments);
        if (this.args._block_identifier !== _BLOCK_IDENTIFIER) {
          throw new Error(
            `Block components cannot be used directly in templates. They can only be rendered inside BlockOutlets.`
          );
        }
      }
    };
  };
}

export function isBlock(component) {
  return component[_BLOCK_IDENTIFIER];
}
