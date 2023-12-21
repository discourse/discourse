import guid from "pretty-text/guid";

/**
 * @typedef {Object} ClassModification
 * @property {Class} latestClass
 * @property {Class} boundaryClass
 * @property {Map<string,function>} baseStaticMethods
 */

/** @type Map<class, ClassModification> */
export const classModifications = new Map();

export const classModificationsKey = Symbol("CLASS_MODIFICATIONS_KEY");
export const stopSymbol = Symbol("STOP_SYMBOL");

export default function allowClassModifications(OriginalClass) {
  OriginalClass[classModificationsKey] = guid();

  return class extends OriginalClass {
    constructor() {
      if (arguments[arguments.length - 1] === stopSymbol) {
        super(...arguments);
        return;
      }

      const id = OriginalClass[classModificationsKey];
      const FinalClass =
        classModifications.get(id)?.latestClass || OriginalClass;

      return new FinalClass(...arguments);
    }
  };
}
