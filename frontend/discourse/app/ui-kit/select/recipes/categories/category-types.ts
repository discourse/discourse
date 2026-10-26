import type Component from "@glimmer/component";
import type { CategoryRecord } from "discourse/lib/category-source";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import type DSelect from "discourse/ui-kit/select/d-select";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";

/** Engine arguments and blocks forwarded by category recipes. */
export type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/** A held category identity, normalized to its numeric site key. */
export type CategoryValue = CategoryRecord | number | string;

/** TODO(typescript-pending): Remove once Site declares its serialized category collections. */
export interface CategorySite extends Site {
  lazy_load_categories?: boolean;
  uncategorized_category_id?: number;
  categories: CategoryRecord[];
  sortedCategories: CategoryRecord[];
  categoriesByParentId: Map<number, CategoryRecord[]>;
}

/** TODO(typescript-pending): Remove once the settings factory declares runtime keys. */
export interface CategorySettings extends SiteSettingsService {
  allow_uncategorized_topics: boolean;
  fixed_category_positions_on_create: boolean;
}

/** Select rows retain the site's record without copying model getters onto the row. */
export interface CategoryItem extends SelectItem {
  /** Numeric category key, or a distinct action/shortcut key. */
  id: number | string;
  /** Accessible row name, including translated action wording. */
  name: string;
  /** The site's category, absent for shortcut rows. */
  category?: CategoryRecord;
}
