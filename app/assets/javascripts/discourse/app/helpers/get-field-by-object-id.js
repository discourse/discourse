import { helper } from "@ember/component/helper";

export function getFieldByObjectId([groupOfObjects, objectId, fieldName]) {
  if (groupOfObjects && objectId && groupOfObjects[objectId]) {
    return groupOfObjects[objectId][fieldName];
  }
  return 0;
}

export default helper(getFieldByObjectId);
