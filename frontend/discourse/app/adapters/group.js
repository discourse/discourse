import RestAdapter from "discourse/adapters/rest";

export default class GroupAdapter extends RestAdapter {
  appendQueryParams(path, findArgs) {
    return super.appendQueryParams(path, findArgs, ".json");
  }
}
