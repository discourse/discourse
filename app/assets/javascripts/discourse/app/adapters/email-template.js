import RestAdapter from "discourse/adapters/rest";

export default class EmailTemplateAdapter extends RestAdapter {
  pathFor(store, type, id) {
    return id === undefined
      ? "/admin/email/templates"
      : `/admin/email/templates/${id}`;
  }
}
