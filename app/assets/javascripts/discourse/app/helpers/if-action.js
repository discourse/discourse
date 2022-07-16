import { helper } from "@ember/component/helper";

function ifAction([fn]) {
  return fn || (() => {});
}

export default helper(ifAction);
