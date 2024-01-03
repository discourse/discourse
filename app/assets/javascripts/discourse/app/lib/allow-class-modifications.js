import guid from "pretty-text/guid";

/**
 * @typedef {Object} ClassModification
 * @property {Class} latestClass
 */

/** @type Map<class, ClassModification> */
export const classModifications = new Map();

export const classModificationsKey = Symbol("CLASS_MODIFICATIONS_KEY");

export default function allowClassModifications(OriginalClass) {
  const id = guid();
  OriginalClass[classModificationsKey] = id;

  const proxyHandler = {
    construct(target, args, newTarget) {
      const latest = classModifications.get(id).latestClass;
      return Reflect.construct(latest, args, newTarget);
    },

    get(target, prop, receiver) {
      const latest = classModifications.get(id).latestClass;

      if (prop === "prototype") {
        // proto needs to match (it's a proxy invariant)
        return Reflect.get(...arguments);
      }

      return Reflect.get(latest, prop, receiver);
    },
  };

  classModifications.set(id, {
    latestClass: OriginalClass,
  });

  return new Proxy(OriginalClass, proxyHandler);
}
