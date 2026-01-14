import RestAdapter from "discourse/adapters/rest";

export default class EmailStyle extends RestAdapter {
  pathFor() {
    return "/admin/customize/email_style";
  }
}
