import Component from "@glimmer/component";
import { type TrustedHTML, trustHTML } from "@ember/template";
import DMenu, {
  type DMenuComponentArgs,
} from "discourse/float-kit/components/d-menu";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";

interface DNameStyleInputSignature {
  Args: {
    /** Accessible name and tooltip of the style trigger, already translated. */
    styleLabel: string;
    /**
     * Hex color, with or without a leading `#`, that tints the preview. An
     * invalid or missing value leaves the default icon color.
     */
    color?: string | null;
    /**
     * Identifier of the style menu. Only one menu per identifier is open at a
     * time, and it prefixes the trigger and content classes.
     */
    identifier?: string;
    /** IDs of the elements that describe the style, such as its error message. */
    styleDescribedBy?: string;
    /** Whether the chosen style is invalid. */
    styleInvalid?: boolean;
  };
  Element: HTMLDivElement;
  Blocks: {
    /** The name input, rendered beside the style trigger. */
    default: [];
    /** A preview of the current style, shown inside the trigger. */
    preview: [];
    /** The style menu's content. */
    content: [
      /** The open menu, for closing it after a choice. */
      menu: DMenuComponentArgs,
    ];
  };
}

/**
 * A name input joined to a button that previews and picks its visual style,
 * such as an icon and a color. The button opens a menu whose content the
 * consumer supplies, so the same row can offer one picker or several tabs.
 *
 * The consumer renders the input itself (usually a FormKit control) in the
 * default block; the row joins its border to the trigger's.
 */
export default class DNameStyleInput extends Component<DNameStyleInputSignature> {
  get colorStyle(): TrustedHTML | undefined {
    const color = this.args.color;
    if (color && isValidHex(color)) {
      return trustHTML(`--d-name-style-input-color: #${normalizeHex(color)}`);
    }
  }

  <template>
    <div class="d-name-style-input" ...attributes>
      <DMenu
        aria-describedby={{@styleDescribedBy}}
        aria-invalid={{if @styleInvalid "true"}}
        style={{this.colorStyle}}
        @ariaLabel={{@styleLabel}}
        @contentClass="d-name-style-input__content"
        @identifier={{if @identifier @identifier "d-name-style-input"}}
        @inlineTabOrder={{true}}
        @title={{@styleLabel}}
        @triggerClass="btn-default d-name-style-input__trigger"
      >
        <:trigger>
          <span class="d-name-style-input__preview">
            {{yield to="preview"}}
          </span>
        </:trigger>
        <:content as |menu|>
          <div class="d-name-style-input__panel">
            {{yield menu to="content"}}
          </div>
        </:content>
      </DMenu>
      {{yield}}
    </div>
  </template>
}
