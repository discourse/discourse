import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("component-for-row", componentForRow);

export default function componentForRow(
  collectionForIdentifier,
  item,
  selectKit
) {
  return selectKit.modifyComponentForRow(collectionForIdentifier, item);
}
