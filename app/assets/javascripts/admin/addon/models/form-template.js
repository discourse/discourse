import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";

export default class FormTemplate extends RestModel {}

FormTemplate.reopenClass({
  findAll() {
    return ajax(`/admin/customize/form-templates.json`).then((model) => {
      return model.form_templates.sort(
        (a, b) => parseFloat(a.id) - parseFloat(b.id)
      );
    });
  },

  findById(id) {
    return ajax(`/admin/customize/form-templates/${id}.json`).then((model) => {
      return model.form_template;
    });
  },
});
