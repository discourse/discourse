import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import {
  handleOffset,
  readShellGeometry,
  widthForHandleOffset,
} from "discourse/lib/page-shell-geometry";
import { PANEL_LIMITS } from "discourse/services/page-shell";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const RESIZE_KEYS = ["ArrowLeft", "ArrowRight", "Home", "End"];

/**
 * Resizes a shell panel. A pointer drag keeps the handle under the pointer,
 * even where a centered shell moves the handle by only part of the width
 * change; keyboard steps change the width directly.
 */
export default class PageShellPanelSeparator extends Component {
  @service pageShell;

  @tracked active = false;

  registerElement = modifier((element) => {
    this.#element = element;
    return () => (this.#element = null);
  });
  #element = null;
  #gesture = null;

  #source = "pointer";

  get label() {
    return i18n(`page_shell.resize_${this.args.panel}`);
  }

  get max() {
    return this.args.panel === "navigation"
      ? this.pageShell.navigationMaxWidth
      : this.pageShell.contextMaxWidth;
  }

  get min() {
    return PANEL_LIMITS[this.args.panel].minWidth;
  }

  get side() {
    return this.args.panel === "navigation" ? "start" : "end";
  }

  get value() {
    return this.args.panel === "navigation"
      ? this.pageShell.effectiveNavigationWidth
      : this.pageShell.effectiveContextWidth;
  }

  @action
  noteKey(event) {
    if (RESIZE_KEYS.includes(event.key)) {
      this.#source = "keyboard";
    }
  }

  @action
  start() {
    this.active = true;
    const shell = this.#element?.closest(".page-shell");
    if (!shell) {
      return;
    }
    const geometry = readShellGeometry(shell, this.pageShell);
    geometry[this.args.panel].width = this.value;
    this.#gesture = {
      geometry,
      startWidth: this.value,
      startOffset: handleOffset(geometry, this.args.panel),
    };
  }

  @action
  resize(size) {
    this.pageShell.previewPanelWidth(this.args.panel, this.#widthFor(size));
  }

  @action
  end(size) {
    this.pageShell.commitPanelWidth(this.args.panel, this.#widthFor(size));
    this.active = false;
    this.#gesture = null;
    this.#source = "pointer";
  }

  /**
   * The separator reports its start size plus the pointer's travel. Map that
   * travel to the width that puts the handle under the pointer.
   */
  #widthFor(size) {
    if (this.#source === "keyboard" || !this.#gesture) {
      return Math.round(size);
    }
    const { geometry, startOffset, startWidth } = this.#gesture;
    return widthForHandleOffset(
      geometry,
      this.args.panel,
      startOffset + size - startWidth,
      this.min,
      this.max
    );
  }

  <template>
    {{! Runs before the separator's own listener, so the source is known first. }}
    <DResizeSeparator
      class={{dConcatClass
        "page-shell__separator"
        (concat "page-shell__separator--" @panel)
        (if this.active "page-shell__separator--active")
      }}
      @axis="horizontal"
      @label={{this.label}}
      @max={{this.max}}
      @min={{this.min}}
      @onResize={{this.resize}}
      @onResizeEnd={{this.end}}
      @onResizeStart={{this.start}}
      @side={{this.side}}
      @value={{this.value}}
      {{this.registerElement}}
      {{on "keydown" this.noteKey}}
    />
  </template>
}
