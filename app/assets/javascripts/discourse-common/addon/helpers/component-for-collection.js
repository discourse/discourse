import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("component-for-collection", componentForCollection);

export default function componentForCollection(
  collectionIdentifier,
  selectKit
) {
  return selectKit.modifyComponentForCollection(collectionIdentifier);
}
