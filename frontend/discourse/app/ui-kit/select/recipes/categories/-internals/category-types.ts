import type Category from "discourse/models/category";
import type SiteSettingsService from "discourse/services/site-settings";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";

/** A held category identity, normalized to its numeric site key. */
export type CategoryValue = Category | number | string;

/** TODO(typescript-pending): Remove once the settings factory declares runtime keys. */
export interface CategorySettings extends SiteSettingsService {
  allow_uncategorized_topics: boolean;
  fixed_category_positions: boolean;
  fixed_category_positions_on_create: boolean;
}

/** Select rows retain the site's record without copying model getters onto the row. */
export interface CategoryItem extends SelectItem {
  /** Numeric category key, or a distinct action/shortcut key. */
  id: number | string;
  /** Accessible row name, including translated action wording. */
  name: string;
  /** The site's category, absent for shortcut rows. */
  category?: Category;
  /** Set on a family's own category only, which groups it alone so its footer follows it. */
  familyKey?: number;
}
