import RestCompatModel from "discourse/data/rest-compat";
import { ArchetypeSchema } from "discourse/data/schemas/archetype";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import { deepEqual } from "discourse/lib/object";
import type Site from "discourse/models/site";

/** A serialized option; option values are supplied by runtime registrations. */
export interface ArchetypeOption {
  key: string;
  title: string;
  description: string;
  option_type: unknown;
}

/** ArchetypeSerializer fields, plus the site attached before construction. */
export interface ArchetypeFields {
  id: string;
  name: string;
  options: ArchetypeOption[];
  site: Site;
}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Archetype extends ArchetypeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Archetype extends RestCompatModel {
  static override type = "archetype";

  declare id: string;

  get hasOptions(): boolean {
    return this.options?.length > 0;
  }

  get isDefault(): boolean {
    return deepEqual(this.id, this.site?.default_archetype);
  }

  get notDefault(): boolean {
    return !this.isDefault;
  }
}

defineFieldForwarders(Archetype, ArchetypeSchema);
