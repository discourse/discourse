import RestAdapter from "discourse/adapters/rest";

export default class ReviewableSettingsAdapter extends RestAdapter {
  pathFor() {
    return "/review/settings";
  }
}
