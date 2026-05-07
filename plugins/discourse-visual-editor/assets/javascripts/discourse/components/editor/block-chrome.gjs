// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";

/**
 * Wraps every rendered block while the editor is active so the canvas can
 * show selection chrome (an outline plus a corner handle when selected).
 *
 * Curried into the block render path via the `BLOCK_DEBUG` debug-hook from
 * the api-initializer. When the editor is inactive, only the wrapped block
 * renders — no extra DOM and no event interception, so the host page
 * behaves exactly as it would without the plugin.
 */
export default class BlockChrome extends Component {
  @service blocks;
  @service visualEditor;

  /**
   * Block metadata (description, namespace, isContainer, args schema, etc.)
   * for the wrapped block, or `null` if the registry has no entry for this
   * block name.
   *
   * `@cached` memoises the lookup per component instance. A future Phase
   * could promote this to a shared service-level cache to avoid every
   * rendered block walking the registry on first access.
   */
  @cached
  get metadata() {
    const index = this.blocks
      .listBlocksWithMetadata()
      .reduce((m, e) => m.set(e.name, e.metadata), new Map());
    return index.get(this.args.blockName) ?? null;
  }

  /** @returns {boolean} */
  get isSelected() {
    return this.visualEditor.isBlockSelected(this.args.blockKey);
  }

  /** @returns {boolean} */
  get isContainer() {
    return this.metadata?.isContainer ?? false;
  }

  /** @returns {string} */
  get displayName() {
    return this.metadata?.shortName ?? this.args.blockName;
  }

  /**
   * Captures the click only when editor is active. Stops propagation so the
   * host page's own click handlers (links, buttons inside the block) don't
   * fire while the user is editing.
   */
  @action
  onClick(event) {
    if (!this.visualEditor.isActive) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.selectBlock({
      key: this.args.blockKey,
      name: this.args.blockName,
      id: this.args.blockId,
      args: this.args.blockArgs,
      containerArgs: this.args.containerArgs,
      conditions: this.args.conditions,
      outletArgs: this.args.outletArgs,
      outletName: this.args.outletName,
      metadata: this.metadata,
    });
  }

  <template>
    {{#if this.visualEditor.isActive}}
      <div
        class={{concatClass
          "visual-editor-block-chrome"
          (if this.isSelected "--selected")
          (if this.isContainer "--container")
        }}
        data-ve-block-name={{@blockName}}
        data-ve-block-key={{@blockKey}}
        {{on "click" this.onClick}}
        role="button"
        tabindex="0"
      >
        {{#if this.isSelected}}
          <span class="visual-editor-block-handle">
            {{icon "cube"}}
            <span>{{this.displayName}}</span>
          </span>
        {{/if}}
        <@WrappedComponent />
      </div>
    {{else}}
      <@WrappedComponent />
    {{/if}}
  </template>
}
