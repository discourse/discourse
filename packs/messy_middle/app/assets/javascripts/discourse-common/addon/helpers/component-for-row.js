import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound(
  "component-for-row",
  (collectionForIdentifier, item, selectKit) => {
    return selectKit.modifyComponentForRow(collectionForIdentifier, item);
  }
);
