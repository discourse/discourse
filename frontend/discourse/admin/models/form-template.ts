import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/** `/admin/customize/form-templates` record; `template` is YAML text. */
export interface FormTemplateFields {
  id: number;
  name: string;
  template: string;
}

/** Form input; new templates have no id. */
export interface FormTemplateInput {
  id?: number;
  name: string;
  template: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface FormTemplate extends FormTemplateFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class FormTemplate extends RestModel {
  static createTemplate(
    data: FormTemplateInput
  ): Promise<{ form_template: FormTemplateFields }> {
    return ajax("/admin/customize/form-templates.json", {
      type: "POST",
      data,
    });
  }

  static updateTemplate(
    id: number | string,
    data: FormTemplateInput
  ): Promise<{ form_template: FormTemplateFields }> {
    return ajax(`/admin/customize/form-templates/${id}.json`, {
      type: "PUT",
      data,
    });
  }

  static createOrUpdateTemplate(
    data: FormTemplateInput
  ): Promise<{ form_template: FormTemplateFields }> {
    if (data.id) {
      return this.updateTemplate(data.id, data);
    } else {
      return this.createTemplate(data);
    }
  }

  static deleteTemplate(id: number | string): Promise<{ success: string }> {
    return ajax(`/admin/customize/form-templates/${id}.json`, {
      type: "DELETE",
    });
  }

  /** Resolves the plain records, not model instances. */
  static async findAll(): Promise<FormTemplateFields[]> {
    // TODO(typescript-pending): ajax has no response generic; remove this assertion when it does.
    const result = (await ajax("/admin/customize/form-templates.json")) as {
      form_templates: FormTemplateFields[];
    };
    return result.form_templates;
  }

  /** Resolves the plain record, not a model instance. */
  static async findById(id: number | string): Promise<FormTemplateFields> {
    // TODO(typescript-pending): ajax has no response generic; remove this assertion when it does.
    const result = (await ajax(
      `/admin/customize/form-templates/${id}.json`
    )) as { form_template: FormTemplateFields };
    return result.form_template;
  }

  /** Previews an unsaved template, so the echoed id can be null. */
  static validateTemplate(data: FormTemplateInput): Promise<{
    form_template: { id: number | null; name: string; template: string };
  }> {
    return ajax(`/admin/customize/form-templates/preview.json`, {
      type: "GET",
      data,
    });
  }
}
