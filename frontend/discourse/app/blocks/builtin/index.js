/**
 * Built-in blocks registry.
 *
 * This module lists all built-in block components provided by Discourse.
 * These blocks are registered at runtime by the `initialize-blocks`
 * initializer, which imports from this file and calls `api.registerBlock()`
 * for each exported block.
 *
 * ## Adding a New Built-in Block
 *
 * 1. Create the block component in `app/blocks/builtin/` with the `@block` decorator:
 *    ```javascript
 *    import Component from "@glimmer/component";
 *    import { block } from "discourse/blocks/block-outlet";
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
 * ## Architecture Note
 *
 * This file is intentionally NOT imported by `registration.js` to avoid
 * circular dependencies. The dependency chain is:
 *
 * ```
 * block-outlet.gjs → registration.js (NO import of builtin/index.js)
 * block-group.gjs → block-outlet.gjs
 * builtin/index.js → block-group.gjs
 * initialize-blocks.js (initializer) → builtin/index.js
 * ```
 *
 * The initializer runs after all modules are loaded, safely importing
 * from this registry without creating cycles.
 *
 * @module discourse/blocks/builtin
 */
export { default as BlockFirstMatch } from "./block-first-match";
export { default as BlockGroup } from "./block-group";
