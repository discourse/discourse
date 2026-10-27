import type Component from "@glimmer/component";
import type Category from "discourse/models/category";
import type Site from "discourse/models/site";
import type SiteSettingsService from "discourse/services/site-settings";
import type DSelect from "discourse/ui-kit/select/d-select";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";

/** Engine arguments and blocks forwarded by category recipes. */
export type SelectSignature =
  DSelect extends Component<infer Signature> ? Signature : never;

/**
 * A site category with the serialized fields used by category recipes and rows.
 * TODO(typescript-pending): Use Category directly once it declares these serialized fields.
 */
export interface CategoryRecord extends Category {
  /** The site's numeric lookup key. */
  id: number;
  /** Serialized category name. */
  name: string;
  /** Direct parent, absent for top-level categories. */
  parent_category_id?: number | null;
  /** Topic creation permission, with 1 granting full access. */
  permission?: number | null;
  /** Topics belonging directly to this category. */
  topic_count?: number;
  /** Whether access is restricted to specific groups. */
  read_restricted?: boolean;
  /** Transformed plain-text description. */
  readonly descriptionText: string | null | undefined;
  /** Direct parent resolved through the site. */
  readonly parentCategory: CategoryRecord | undefined;
  /** Ancestors ordered from the nearest parent outward. */
  readonly predecessors: CategoryRecord[];
  /** Own topic count plus the direct children's topics. */
  readonly totalTopicCount: number | undefined;
  /** Whether unloaded descendants may exist. */
  has_children?: boolean;
}

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
