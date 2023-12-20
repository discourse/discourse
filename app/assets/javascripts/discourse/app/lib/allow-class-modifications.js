import guid from "pretty-text/guid";

/** @type Map<class, Set<class>> */
export const classModifications = new Map();
export const classModificationsKey = Symbol("CLASS_MODIFICATIONS_KEY");

const stopSymbol = Symbol("STOP_SYMBOL");

export default function allowClassModifications(OriginalClass) {
  OriginalClass[classModificationsKey] = guid();

  return class extends OriginalClass {
    constructor() {
      if (arguments[arguments.length - 1] === stopSymbol) {
        return;
      }

      const id = OriginalClass[classModificationsKey];
      const FinalClass = classModifications.get(id) || OriginalClass;

      // eslint-disable-next-line no-new
      new FinalClass(...arguments, stopSymbol);
    }
  };
}
