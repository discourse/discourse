import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("component-for-collection", componentForCollection);

export default function componentForCollection(
  collectionIdentifier,
  selectKit
) {
  return selectKit.modifyComponentForCollection(collectionIdentifier);
}
