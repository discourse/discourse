import { helper } from "@ember/component/helper";
import getUrl from "discourse-common/lib/get-url";

export function generateUsersLink(val) {
  const url = getUrl(`/u?name=${encodeURIComponent(val)}`);
  return `<a href="${url}">${val}</a>`;
}

export default helper(generateUsersLink);
