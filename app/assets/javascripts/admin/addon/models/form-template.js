import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";

export default class FormTemplate extends RestModel {
  static createTemplate(data) {
    return ajax("/admin/customize/form-templates.json", {
      type: "POST",
      data,
    });
  }

  static updateTemplate(id, data) {
    return ajax(`/admin/customize/form-templates/${id}.json`, {
      type: "PUT",
      data,
    });
  }

  static createOrUpdateTemplate(data) {
    if (data.id) {
      return this.updateTemplate(data.id, data);
    } else {
      return this.createTemplate(data);
    }
  }

  static deleteTemplate(id) {
    return ajax(`/admin/customize/form-templates/${id}.json`, {
      type: "DELETE",
    });
  }

  static async findAll() {
    const result = await ajax("/admin/customize/form-templates.json");
    return result.form_templates;
  }

  static async findById(id) {
    const result = await ajax(`/admin/customize/form-templates/${id}.json`);
    return result.form_template;
  }

  static validateTemplate(data) {
    return ajax(`/admin/customize/form-templates/preview.json`, {
      type: "GET",
      data,
    });
  }
}
