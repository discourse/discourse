import RestAdapter from "discourse/adapters/rest";

export default class ReviewableAdapter extends RestAdapter {
  jsonMode = true;

  pathFor(store, type, findArgs) {
    if (!findArgs?.ids) {
      return this.appendQueryParams("/review", findArgs);
    }

    const { ids: rawIds, ...queryParams } = findArgs;
    const ids = Array.isArray(rawIds) ? rawIds : [rawIds];
    const path = this.appendQueryParams("/review", queryParams);
    const separator = path.includes("?") ? "&" : "?";
    const idParams = ids
      .map((id) => `ids[]=${encodeURIComponent(id)}`)
      .join("&");

    return `${path}${separator}${idParams}`;
  }
}
