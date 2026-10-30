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
    // TODO(typescript-pending): remove the response assertion when ajax supports typed payloads.
    const result = (await ajax("/form-templates.json")) as {
      form_templates: FormTemplatePayload[];
    };
    return result.form_templates;
  }

  /** Returns the entire show envelope, unlike the index factory's array. */
  static async findById(
    id: number
  ): Promise<{ form_template: FormTemplatePayload }> {
    return await ajax(`/form-templates/${id}.json`);
  }
}
