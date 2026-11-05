import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import RestModel from "discourse/models/rest";
import { i18n } from "discourse-i18n";

export type UserFieldKind =
  | "text"
  | "textarea"
  | "date"
  | "confirm"
  | "dropdown"
  | "multiselect";

/** `/admin/config/user_fields` record; new records start with only the route defaults. */
export interface UserFieldFields {
  id?: number;
  name?: string;
  description?: string;
  required?: boolean;
  show_on_signup: boolean;
  position?: number | null;
  /** Only option-bearing field types send options. */
  options?: string[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserField extends UserFieldFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserField extends RestModel {
  static fieldTypes(): UserFieldType[] {
    if (!this._fieldTypes) {
      this._fieldTypes = [
        UserFieldType.create({ id: "text" }),
        UserFieldType.create({ id: "textarea" }),
        UserFieldType.create({ id: "date" }),
        UserFieldType.create({ id: "confirm" }),
        UserFieldType.create({ id: "dropdown", hasOptions: true }),
        UserFieldType.create({ id: "multiselect", hasOptions: true }),
      ];
    }

    return this._fieldTypes;
  }

  static fieldTypeById(id: string | undefined): UserFieldType | undefined {
    return this.fieldTypes().find((value) => value.id === id);
  }

  @tracked field_type!: UserFieldKind;

  @tracked editable: boolean | undefined;
  @tracked show_on_profile: boolean | undefined;
  @tracked show_on_user_card: boolean | undefined;
  @tracked searchable: boolean | undefined;
  @tracked requirement!: "optional" | "for_all_users" | "on_signup";
  declare static _fieldTypes?: UserFieldType[];

  get fieldTypeName(): string {
    return UserField.fieldTypes().find((ft) => ft.id === this.field_type)!.name;
  }
}

class UserFieldType extends EmberObject {
  @tracked id!: UserFieldKind;

  declare hasOptions?: boolean;

  @dependentKeyCompat
  get name(): string {
    return i18n(`admin.user_fields.field_types.${this.id}`);
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "user-field": UserField;
  }
}
