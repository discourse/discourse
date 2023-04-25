import { helper } from "@ember/component/helper";

export function getHeartPower([groupOfObjects, objectId, fieldName]) {
  if (groupOfObjects && objectId && groupOfObjects[objectId]) {
    return groupOfObjects[objectId][fieldName] ** 0.5;
  }
  return 0;
}

export default helper(getHeartPower);
