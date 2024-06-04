import { DEBUG } from "@glimmer/env";
import { isTesting } from "discourse-common/config/environment";

const RESERVED_CLASS_PROPS = ["prototype", "name", "length"];
const RESERVED_PROTOTYPE_PROPS = ["constructor"];

/**
 * This function provides a way to add/modify instance and static properties on an existing JS class, including
 * the ability to use `super` to call the original implementation.
 *
 * It DOES NOT support modifying the constructor or adding/modifying native class fields. Some decorated fields
 * (e.g. Ember's `@tracked`) can be added/modified, because the decorator turns these fields into getters/setters.
 *
 */
export default function classPrepend(klass, callback) {
  const originalKlassDescs = Object.getOwnPropertyDescriptors(klass);
  const originalProtoDescs = Object.getOwnPropertyDescriptors(klass.prototype);
  logDescriptorInfoForRollback(klass, originalKlassDescs, originalProtoDescs);

  for (const key of RESERVED_CLASS_PROPS) {
    delete originalKlassDescs[key];
  }

  for (const key of RESERVED_PROTOTYPE_PROPS) {
    delete originalProtoDescs[key];
  }

  // Make a fake class which is a copy of the klass at this point in time. This provides the 'super'
  // implementation.
  const FakeSuperclass = class {};
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

let originalDescriptorInfo;

if (DEBUG && isTesting()) {
  originalDescriptorInfo = new Map();
}

function logDescriptorInfoForRollback(klass, klassDescs, protoDescs) {
  if (DEBUG && isTesting() && !originalDescriptorInfo.has(klass)) {
    originalDescriptorInfo.set(klass, {
      klassDescs,
      protoDescs,
    });
  }
}

/**
 * Rollback all descriptors to their original values. This should only be used in tests
 */
export function rollbackAllModifications() {
  if (DEBUG && isTesting()) {
    for (const [klass, { klassDescs, protoDescs }] of originalDescriptorInfo) {
      for (const [key, descriptor] of Object.entries(klassDescs)) {
        Object.defineProperty(klass, key, descriptor);
      }

      for (const [key, descriptor] of Object.entries(protoDescs)) {
        Object.defineProperty(klass.prototype, key, descriptor);
      }
    }

    originalDescriptorInfo.clear();
  }
}
