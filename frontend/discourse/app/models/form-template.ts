import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/** Plain JSON returned by the form-template endpoints, rather than a model instance. */
export interface FormTemplatePayload {
  id: number;
  name: string;
  template: string;
}

export default class FormTemplate extends RestModel {
  static async findAll(): Promise<FormTemplatePayload[]> {
    const result = await ajax<{
      form_templates: FormTemplatePayload[];
    }>("/form-templates.json");
    return result.form_templates;
  }

  /** Returns the entire show envelope, unlike the index factory's array. */
  static async findById(
    id: number
  ): Promise<{ form_template: FormTemplatePayload }> {
    return await ajax(`/form-templates/${id}.json`);
  }
}
