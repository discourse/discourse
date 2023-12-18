import guid from "pretty-text/guid";

/** @type Map<class, Set<class>> */
export const classModifications = new Map();
export const classModificationsKey = Symbol("CLASS_MODIFICATIONS_KEY");

export default function allowClassModifications(OriginalClass) {
  OriginalClass[classModificationsKey] = guid();

  return class extends OriginalClass {
    constructor() {
      const id = OriginalClass[classModificationsKey];
      const modificationSet = classModifications.get(id);
      let FinalClass = OriginalClass;

      if (modificationSet) {
        for (const modification of modificationSet) {
          FinalClass = modification(FinalClass);
        }

        Object.defineProperty(FinalClass, "name", {
          value: OriginalClass.name,
        });

        FinalClass[classModificationsKey] = id;
      }

      return new FinalClass(...arguments);
    }
  };
}
