/**
 * Built-in blocks registry.
 *
 * This module lists all built-in block components provided by Discourse.
 * These blocks are registered at runtime by the `freeze-block-registry`
 * initializer, which imports from this file and calls `api.registerBlock()`
 * for each exported block.
 *
 * ## Adding a New Built-in Block
 *
 * 1. Create the block component in `app/blocks/builtin/` with the `@block` decorator:
 *    ```javascript
 *    import Component from "@glimmer/component";
 *    import { block } from "discourse/blocks";
 *
 *    @block("my-block")
 *    export default class MyBlock extends Component {
 *      // ...
 *    }
 *    ```
 *
 * 2. Add an export to this file:
 *    ```javascript
 *    export { default as MyBlock } from "discourse/blocks/builtin/my-block";
 *    ```
 *
 * The initializer automatically picks up any new exports and registers them.
 *
 * @module discourse/blocks/builtin
 */
export { default as BlockHead } from "./block-head";
export { default as BlockGroup } from "./block-group";
export { default as Heading } from "./heading";
export { default as Paragraph } from "./paragraph";
export { default as Image } from "./image";
export { default as ButtonLink } from "./button-link";
export { default as Layout } from "./layout";
export { default as Spacer } from "./spacer";
export { default as Divider } from "./divider";
export { default as Callout } from "./callout";
export { default as CtaBanner } from "./cta-banner";
export { default as CategoryBanner } from "./category-banner";
export { default as FeaturedCategories } from "./featured-categories";
export { default as RecentTopics } from "./recent-topics";
export { default as FeaturedTopics } from "./featured-topics";
export { default as MediaCard } from "./media-card";
