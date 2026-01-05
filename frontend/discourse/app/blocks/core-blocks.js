/**
 * Core blocks registry.
 *
 * This module lists all core block components provided by Discourse.
 * These blocks are registered at runtime by the `register-core-blocks`
 * instance-initializer, which imports from this file and calls
 * `api.registerBlock()` for each exported block.
 *
 * ## Adding a New Core Block
 *
 * 1. Create the block component in `app/blocks/` with the `@block` decorator:
 *    ```javascript
 *    import Component from "@glimmer/component";
 *    import { block } from "discourse/components/block-outlet";
 *
 *    @block("my-block")
 *    export default class MyBlock extends Component {
 *      // ...
 *    }
 *    ```
 *
 * 2. Add an export to this file:
 *    ```javascript
 *    export { default as MyBlock } from "discourse/blocks/my-block";
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
 * block-outlet.gjs → registration.js (NO import of core-blocks.js)
 * block-group.gjs → block-outlet.gjs
 * core-blocks.js → block-group.gjs
 * register-core-blocks.js (initializer) → core-blocks.js
 * ```
 *
 * The initializer runs after all modules are loaded, safely importing
 * from this registry without creating cycles.
 *
 * @module discourse/blocks/core-blocks
 */
export { default as BlockGroup } from "discourse/blocks/block-group";
