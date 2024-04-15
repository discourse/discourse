import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("component-for-row", componentForRow);

export default function componentForRow(
  collectionForIdentifier,
  item,
  selectKit
) {
  return selectKit.modifyComponentForRow(collectionForIdentifier, item);
}
