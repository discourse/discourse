import CoreObject from "@ember/object/core";

const RESERVED_CLASS_PROPS = ["prototype", "name", "length"];
const RESERVED_PROTOTYPE_PROPS = ["constructor"];

function hasAncestor(klass, ancestor) {
  let current = klass;
  while (current) {
    if (current === ancestor) {
      return true;
    }
    current = Object.getPrototypeOf(current);
  }
  return false;
}

/**
 * This function provides a way to add/modify instance and static properties on an existing JS class, including
 * the ability to use `super` to call the original implementation.
 *
 * It DOES NOT support modifying the constructor or adding/modifying native class fields. Some decorated fields
 * (e.g. Ember's `@tracked`) can be added/modified, because the decorator turns these fields into getters/setters.
 *
 */
export default function classPrepend(klass, callback) {
  if (hasAncestor(klass, CoreObject)) {
    // Ensure any prior reopen() calls have been applied
    klass.proto();
  }

  const originalKlassDescs = Object.getOwnPropertyDescriptors(klass);
  const originalProtoDescs = Object.getOwnPropertyDescriptors(klass.prototype);
  logInfo(klass, originalKlassDescs, originalProtoDescs, callback);

  for (const key of RESERVED_CLASS_PROPS) {
    delete originalKlassDescs[key];
  }

  for (const key of RESERVED_PROTOTYPE_PROPS) {
    delete originalProtoDescs[key];
  }

  // Make a fake class which is a copy of the klass at this point in time. This provides the 'super'
  // implementation.
  const klassProto = Object.getPrototypeOf(klass);
  const FakeSuperclass =
    klassProto !== Function.prototype ? class extends klassProto {} : class {};
  Object.defineProperties(FakeSuperclass, originalKlassDescs);
  Object.defineProperties(FakeSuperclass.prototype, originalProtoDescs);

  const modifiedKlass = callback(FakeSuperclass);

  if (Object.getPrototypeOf(modifiedKlass) !== FakeSuperclass) {
    throw new Error(
      "The class returned from the callback must extend the provided superclass"
    );
  }

  // Apply any new/modified klass descriptors to the original class
  const newKlassDescs = Object.getOwnPropertyDescriptors(modifiedKlass);
  for (const [key, descriptor] of Object.entries(newKlassDescs)) {
    if (
      originalKlassDescs[key] !== descriptor &&
      !RESERVED_CLASS_PROPS.includes(key)
    ) {
      Object.defineProperty(klass, key, descriptor);
    }
  }

  // Apply any new/modified prototype descriptors to the original class
  const newProtoDescs = Object.getOwnPropertyDescriptors(
    modifiedKlass.prototype
  );
  for (const [key, descriptor] of Object.entries(newProtoDescs)) {
    if (
      originalProtoDescs[key] !== descriptor &&
      !RESERVED_PROTOTYPE_PROPS.includes(key)
    ) {
      Object.defineProperty(klass.prototype, key, descriptor);
    }
  }
}

const prependInfo = new Map();

/**
 * Log the previous state of a class so that it can be rolled back later.
 */
function logInfo(klass, klassDescs, protoDescs, modifyCallback) {
  const info = prependInfo.get(klass) || {
    klassDescs,
    protoDescs,
    modifyCallbacks: [],
  };
  info.modifyCallbacks.push(modifyCallback);
  prependInfo.set(klass, info);
}

/**
 * Rollback a specific class to its state before any prepends were applied.
 */
function rollbackPrepends(klass) {
  const { klassDescs, protoDescs } = prependInfo.get(klass);

  for (const [key, descriptor] of Object.entries(klassDescs)) {
    Object.defineProperty(klass, key, descriptor);
  }

  for (const key of Object.getOwnPropertyNames(klass)) {
    if (!RESERVED_CLASS_PROPS.includes(key) && !klassDescs[key]) {
      delete klass[key];
    }
  }

  for (const [key, descriptor] of Object.entries(protoDescs)) {
    Object.defineProperty(klass.prototype, key, descriptor);
  }

  for (const key of Object.getOwnPropertyNames(klass.prototype)) {
    if (!RESERVED_PROTOTYPE_PROPS.includes(key) && !protoDescs[key]) {
      delete klass.prototype[key];
    }
  }

  prependInfo.delete(klass);
}

/**
 * Rollback all prepends on a class, run a callback, then re-apply the prepends.
 */
export function withPrependsRolledBack(klass, callback) {
  const info = prependInfo.get(klass);
  if (!info) {
    callback();
    return;
  }

  rollbackPrepends(klass);
  try {
    callback();
  } finally {
    info.modifyCallbacks.forEach((cb) => classPrepend(klass, cb));
  }
}

/**
 * Rollback all descriptors to their original values. This should only be used in tests
 */
export function rollbackAllPrepends() {
  for (const klass of prependInfo.keys()) {
    rollbackPrepends(klass);
  }
}
