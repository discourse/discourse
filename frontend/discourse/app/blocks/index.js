const BLOCKS = new WeakSet();

export function block(name) {
  return function (target) {
    target.blockName = name;
    BLOCKS.add(target);
    return target;
  };
}

export function isBlock(component) {
  return BLOCKS.has(component);
}
