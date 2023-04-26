import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class FormTemplate extends RestModel {
  static findById(id) {
    return ajax(`/form-templates/${id}.json`);
  }
}
