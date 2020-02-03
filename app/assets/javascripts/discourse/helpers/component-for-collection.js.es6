import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound(
  "component-for-collection",
  (collectionIdentifier, selectKit) => {
    return selectKit.modifyComponentForCollection(collectionIdentifier);
  }
);
