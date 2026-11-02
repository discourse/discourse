import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import ColorSchemeColor from "discourse/admin/models/color-scheme-color";
import { ajax } from "discourse/lib/ajax";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

/** A palette color as the server sends it. */
export interface ColorSchemeColorPayload {
  name: string;
  hex: string;
  default_hex: string | null;
  is_advanced: boolean;
}

/** `/admin/color_schemes` and `/admin/config/colors/:id` record. */
export interface ColorSchemePayload {
  id: number;
  name: string;
  is_base: boolean | null;
  base_scheme_id: number | null;
  theme_id: number | null;
  theme_name: string | null;
  user_selectable: boolean;
  is_builtin_default: boolean | null;
  /** Null for a palette with no colors. */
  is_dark: boolean | null;
  colors: ColorSchemeColorPayload[];
}

/** Server metadata is optional: the manager builds id-only instances and copies omit it. */
export interface ColorSchemeFields {
  is_base?: boolean | null;
  is_builtin_default?: boolean | null;
  is_dark?: boolean | null;
  theme_id?: number | null;
  theme_name?: string | null;
  base_scheme_id?: number | null;
  can_edit?: boolean;
  default_light_on_theme?: boolean;
  default_dark_on_theme?: boolean;
  saving?: boolean;
  savingStatus?: string | null;
  originals: { name: string | undefined; user_selectable: boolean | undefined };
}

/** `init` turns raw color records into ColorSchemeColor instances. */
export type ColorSchemeCreateAttrs<M = ColorScheme> = Partial<
  Omit<M, "colors">
> & {
  colors?: (Partial<ColorSchemeColorPayload> | ColorSchemeColor)[];
};

export interface ColorSchemeSaveOptions {
  forceSave?: boolean;
  saveNameOnly?: boolean;
  enabledOnly?: boolean;
}

class ColorSchemes extends LegacyArrayLikeObject<ColorScheme> {
  @tracked loading = false;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ColorScheme extends ColorSchemeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ColorScheme extends EmberObject {
  declare static create: <
    C extends abstract new (...args: never[]) => EmberObject,
  >(
    this: C,
    attrs?: ColorSchemeCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  static async findAll(): Promise<ColorSchemes> {
    const colorSchemes = ColorSchemes.create({ content: [], loading: true });
    const all = await ajax<ColorSchemePayload[]>("/admin/color_schemes");

    all.forEach((colorScheme) => {
      // The proxy forwards array methods to `content`.
      (colorSchemes as unknown as ColorScheme[]).push(
        ColorScheme.create({
          id: colorScheme.id,
          name: colorScheme.name,
          is_base: colorScheme.is_base,
          theme_id: colorScheme.theme_id,
          theme_name: colorScheme.theme_name,
          base_scheme_id: colorScheme.base_scheme_id,
          user_selectable: colorScheme.user_selectable,
          colors: colorScheme.colors,
        })
      );
    });

    return colorSchemes;
  }

  static async find(id: number | string): Promise<ColorScheme> {
    const json = await ajax<ColorSchemePayload>(`/admin/config/colors/${id}`);
    return ColorScheme.create({
      id: json.id,
      name: json.name,
      is_base: json.is_base,
      theme_id: json.theme_id,
      theme_name: json.theme_name,
      base_scheme_id: json.base_scheme_id,
      user_selectable: json.user_selectable,
      colors: json.colors,
    });
  }

  @tracked name: string | undefined;
  @tracked user_selectable: boolean | undefined;
  @tracked id: number | undefined;
  @autoTrackedArray colors!: ColorSchemeColor[];

  init(...args: Parameters<EmberObject["init"]>) {
    super.init(...args);

    const colors = this.colors ?? [];
    this.colors = colors.map((c) => {
      return ColorSchemeColor.create(c);
    });
    this.startTrackingChanges();
  }

  @dependentKeyCompat
  get newRecord(): boolean {
    return !this.id;
  }

  @computed
  get description(): string {
    return "" + this.name;
  }

  @computed("name", "user_selectable", "colors.@each.changed", "saving")
  get changed(): boolean {
    if (!this.originals) {
      return false;
    }
    if (this.originals.name !== this.name) {
      return true;
    }
    if (this.originals.user_selectable !== this.user_selectable) {
      return true;
    }
    if (this.colors.some((c) => c.get("changed"))) {
      return true;
    }

    return false;
  }

  @computed("changed")
  get disableSave(): boolean {
    if (this.theme_id) {
      return false;
    }

    return (
      !this.changed || this.saving || this.colors.some((c) => !c.get("valid"))
    );
  }

  startTrackingChanges(): void {
    this.set("originals", {
      name: this.name,
      user_selectable: this.user_selectable,
    });
  }

  schemeJson(): string {
    const buffer: string[] = [];
    this.colors.forEach((c) => {
      buffer.push(`  "${c.get("name")}": "${c.get("hex")}"`);
    });

    return [`"${this.name}": {`, buffer.join(",\n"), "}"].join("\n");
  }

  schemeObject(): {
    name: string | undefined;
    light: Record<string, string | null | undefined>;
  } {
    return {
      name: this.name,
      light: Object.fromEntries(
        this.colors.map((color) => [color.name, color.hex])
      ),
    };
  }

  /**
   * @returns a JSON representation of the color scheme.
   */
  dump(): string {
    return JSON.stringify(this.schemeObject(), null, 2);
  }

  copy(): ColorScheme {
    const newScheme = ColorScheme.create({
      name: this.name,
      can_edit: true,
      colors: [],
    });
    this.colors.forEach((c) => {
      newScheme.colors.push(
        ColorSchemeColor.create(c.getProperties("name", "hex", "default_hex"))
      );
    });
    return newScheme;
  }

  save(opts?: ColorSchemeSaveOptions): Promise<void> | undefined {
    if (!opts?.forceSave && (this.is_base || this.disableSave)) {
      return;
    }

    this.setProperties({ savingStatus: i18n("saving"), saving: true });

    const data: {
      name?: string;
      user_selectable?: boolean;
      default_light_on_theme?: boolean;
      default_dark_on_theme?: boolean;
      base_scheme_id?: number | null;
      colors?: Pick<ColorSchemeColor, "name" | "hex">[];
    } = {};
    if (!opts || !opts.enabledOnly) {
      data.name = this.name;

      if (!opts?.saveNameOnly) {
        data.user_selectable = this.user_selectable;
        data.default_light_on_theme = this.default_light_on_theme;
        data.default_dark_on_theme = this.default_dark_on_theme;
        data.base_scheme_id = this.base_scheme_id;
        data.colors = [];
        this.colors.forEach((c) => {
          if (!this.id || c.get("changed")) {
            data.colors!.push(c.getProperties("name", "hex"));
          }
        });
      }
    }

    return ajax(`/admin/color_schemes${this.id ? `/${this.id}` : ""}.json`, {
      data: JSON.stringify({ color_scheme: data }),
      type: this.id ? "PUT" : "POST",
      dataType: "json",
      contentType: "application/json",
    }).then((result: ColorSchemePayload) => {
      if (result.id) {
        this.set("id", result.id);
      }
      this.set("base_scheme_id", result.base_scheme_id);

      if (!opts?.saveNameOnly) {
        if (!opts || !opts.enabledOnly) {
          this.startTrackingChanges();
          this.colors.forEach((c) => c.startTrackingChanges());
        }
      }

      this.setProperties({ savingStatus: i18n("saved"), saving: false });
      this.notifyPropertyChange("description");
    });
  }

  updateUserSelectable(
    value: boolean
  ): Promise<ColorSchemePayload> | undefined {
    if (!this.id) {
      return;
    }

    return ajax(`/admin/color_schemes/${this.id}.json`, {
      data: JSON.stringify({ color_scheme: { user_selectable: value } }),
      type: "PUT",
      dataType: "json",
      contentType: "application/json",
    });
  }

  updateDefaultOnTheme(
    field: "default_light_on_theme" | "default_dark_on_theme",
    value: boolean
  ): Promise<ColorSchemePayload> | undefined {
    if (!this.id) {
      return;
    }

    return ajax(`/admin/color_schemes/${this.id}.json`, {
      data: JSON.stringify({ color_scheme: { [field]: value } }),
      type: "PUT",
      dataType: "json",
      contentType: "application/json",
    });
  }

  /** Deletes the palette on the server, unlike EmberObject's `destroy`. */
  destroy(this: never): never;
  destroy(): Promise<{ success: string }> | undefined;
  destroy(): Promise<{ success: string }> | undefined {
    if (this.id) {
      return ajax(`/admin/color_schemes/${this.id}`, { type: "DELETE" });
    }
  }
}
