import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";

export default class FormTemplate extends RestModel {}

FormTemplate.reopenClass({
  createTemplate(data) {
    return ajax("/admin/customize/form-templates.json", {
      type: "POST",
      data,
    });
  },

  updateTemplate(id, data) {
    return ajax(`/admin/customize/form-templates/${id}.json`, {
      type: "PUT",
      data,
    });
  },

  createOrUpdateTemplate(data) {
    if (data.id) {
      return this.updateTemplate(data.id, data);
    } else {
      return this.createTemplate(data);
    }
  },

  deleteTemplate(id) {
    return ajax(`/admin/customize/form-templates/${id}.json`, {
      type: "DELETE",
    });
  },

  findAll() {
    return ajax(`/admin/customize/form-templates.json`).then((model) => {
      return model.form_templates.sort((a, b) => a.id - b.id);
    });
  },

  findById(id) {
    return ajax(`/admin/customize/form-templates/${id}.json`).then((model) => {
      return model.form_template;
    });
  },

  validateTemplate(data) {
    return ajax(`/admin/customize/form-templates/preview.json`, {
      type: "GET",
      data,
    });
  },
});
