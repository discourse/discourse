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
