// @ts-check
import { withPluginApi } from "discourse/lib/plugin-api";
import VEBadgesGrid from "../blocks/ve-badges-grid";
import VEButtonLink from "../blocks/ve-button-link";
import VECallout from "../blocks/ve-callout";
import VECategoryBanner from "../blocks/ve-category-banner";
import VEColumns from "../blocks/ve-columns";
import VECTABanner from "../blocks/ve-cta-banner";
import VEDivider from "../blocks/ve-divider";
import VEFeaturedCategories from "../blocks/ve-featured-categories";
import VEHeading from "../blocks/ve-heading";
import VEImage from "../blocks/ve-image";
import VELayout from "../blocks/ve-layout";
import VEParagraph from "../blocks/ve-paragraph";
import VERecentTopics from "../blocks/ve-recent-topics";
import VESlot from "../blocks/ve-slot";
import VESpacer from "../blocks/ve-spacer";

const STARTER_BLOCKS = [
  VEHeading,
  VEParagraph,
  VEImage,
  VEButtonLink,
  VELayout,
  VESlot,
  VESpacer,
  VEDivider,
  // ve:columns stays registered (paletteHidden) so existing layouts
  // referencing it continue to resolve. Authors should use ve:layout.
  VEColumns,
  VECallout,
  VECTABanner,
  VECategoryBanner,
  VEFeaturedCategories,
  VERecentTopics,
  VEBadgesGrid,
];

/**
 * Registers the visual editor's starter block library. Each block is a
 * thin wrapper around an existing ui-kit primitive (or static markup,
 * for the data-driven ones) so the palette has something useful to
 * offer out of the box.
 *
 * Pre-initializer rather than api-initializer because the blocks
 * registry is frozen by the `freeze-block-registry` initializer; any
 * `api.registerBlock(...)` call after that point throws. Pre-initializers
 * run before initializers, so registration lands while the registry is
 * still mutable.
 */
export default {
  name: "discourse-visual-editor:register-starter-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      for (const klass of STARTER_BLOCKS) {
        api.registerBlock(klass);
      }
    });
  },
};
