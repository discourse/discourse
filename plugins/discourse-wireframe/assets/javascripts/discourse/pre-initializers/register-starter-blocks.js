// @ts-check
import { withPluginApi } from "discourse/lib/plugin-api";
import WFBadgesGrid from "../blocks/wf-badges-grid";
import WFButtonLink from "../blocks/wf-button-link";
import WFCallout from "../blocks/wf-callout";
import WFCategoryBanner from "../blocks/wf-category-banner";
import WFColumns from "../blocks/wf-columns";
import WFCTABanner from "../blocks/wf-cta-banner";
import WFDivider from "../blocks/wf-divider";
import WFFeaturedCategories from "../blocks/wf-featured-categories";
import WFFeaturedTopics from "../blocks/wf-featured-topics";
import WFHeading from "../blocks/wf-heading";
import WFImage from "../blocks/wf-image";
import WFLayout from "../blocks/wf-layout";
import WFMediaCard from "../blocks/wf-media-card";
import WFParagraph from "../blocks/wf-paragraph";
import WFRecentTopics from "../blocks/wf-recent-topics";
import WFSlot from "../blocks/wf-slot";
import WFSpacer from "../blocks/wf-spacer";

const STARTER_BLOCKS = [
  WFHeading,
  WFParagraph,
  WFImage,
  WFButtonLink,
  WFLayout,
  WFSlot,
  WFSpacer,
  WFDivider,
  // wf:columns stays registered (paletteHidden) so existing layouts
  // referencing it continue to resolve. Authors should use wf:layout.
  WFColumns,
  WFCallout,
  WFCTABanner,
  WFCategoryBanner,
  WFFeaturedCategories,
  WFRecentTopics,
  WFFeaturedTopics,
  WFMediaCard,
  WFBadgesGrid,
];

/**
 * Registers the wireframe's starter block library. Each block is a
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
  name: "discourse-wireframe:register-starter-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      for (const klass of STARTER_BLOCKS) {
        api.registerBlock(klass);
      }
    });
  },
};
