import Component from "@glimmer/component";
import type { BlockDataComponent } from "discourse/blocks/types";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

interface BlockPanelSignature<Value> {
  Args: {
    /** The panel heading, shown when no `:header` block is given. */
    title?: string;
    /** An icon shown before the title. */
    icon?: string;
    /**
     * The block's data-region boundary. When given, the body loads through it
     * and shows the block's skeleton, empty state and a retry on failure.
     */
    Data?: BlockDataComponent<Value>;
  };
  Blocks: {
    /** Replaces the default icon and title heading. */
    header: [];
    /** The panel body, yielding the resolved data when `@Data` is given. */
    content: [value: Value | null];
    /** Rendered in the body when the resolved data is empty. */
    empty: [];
    /** Rendered below the body, visible while the data loads. */
    footer: [];
  };
  Element: HTMLElement;
}

/*
 * Shared frame for blocks shown as a panel: a header, a body and a footer.
 * Only the body depends on loaded data, so the header and footer stay visible
 * while it loads.
 */
export default class BlockPanel<Value = unknown> extends Component<
  BlockPanelSignature<Value>
> {
  <template>
    <section class="d-block-panel" ...attributes>
      {{#if (has-block "header")}}
        <header class="d-block-panel__header">{{yield to="header"}}</header>
      {{else if @title}}
        <header class="d-block-panel__header">
          {{#if @icon}}
            <span class="d-block-panel__icon">{{dIcon @icon}}</span>
          {{/if}}
          <h3 class="d-block-panel__title">{{@title}}</h3>
        </header>
      {{/if}}

      <div class="d-block-panel__body">
        {{#if @Data}}
          <@Data>
            <:content as |value|>{{yield value to="content"}}</:content>
            <:empty>{{yield to="empty"}}</:empty>
            <:error as |error inlineError retry|>
              <div class="d-block-panel__error">
                <p class="d-block-panel__error-message" role="alert">
                  {{i18n "blocks.panel.load_error"}}
                </p>
                <DButton
                  class="btn-small d-block-panel__retry"
                  @action={{retry}}
                  @label="blocks.panel.retry"
                />
              </div>
            </:error>
          </@Data>
        {{else}}
          {{yield null to="content"}}
        {{/if}}
      </div>

      {{#if (has-block "footer")}}
        <footer class="d-block-panel__footer">{{yield to="footer"}}</footer>
      {{/if}}
    </section>
  </template>
}
