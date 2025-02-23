import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { buildWaiter } from "@ember/test-waiters";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import loadAce from "discourse/lib/load-ace-editor";
import { i18n } from "discourse-i18n";

const WAITER = buildWaiter("ace-editor");
const COLOR_VARS_REGEX =
  /\$(primary|secondary|tertiary|quaternary|header_background|header_primary|highlight|danger|success|love)(\s|;|-(low|medium|high))/g;

function overridePlaceholder(ace) {
  const originalPlaceholderSetter =
    ace.config.$defaultOptions.editor.placeholder.set;

  ace.config.$defaultOptions.editor.placeholder.set = function () {
    if (!this.$updatePlaceholder) {
      const originalRendererOn = this.renderer.on;
      this.renderer.on = function () {};
      originalPlaceholderSetter.call(this, ...arguments);
      this.renderer.on = originalRendererOn;

      const originalUpdatePlaceholder = this.$updatePlaceholder;

      this.$updatePlaceholder = function () {
        originalUpdatePlaceholder.call(this, ...arguments);

        if (this.renderer.placeholderNode) {
          this.renderer.placeholderNode.innerHTML = this.$placeholder || "";
        }
      }.bind(this);

      this.on("input", this.$updatePlaceholder);
    }

    this.$updatePlaceholder();
  };
}

// Args:
// @content
// @mode
// @disabled (boolean)
// @onChange
// @editorId
// @theme
// @autofocus
// @placeholder
// @htmlPlaceholder (boolean)
// @save
// @submit
// @setWarning
export default class AceEditor extends Component {
  @service appEvents;

  @tracked isLoading = true;
  editor = null;
  ace = null;
  skipChangePropagation = false;

  setContent = modifier(() => {
    if (this.args.content === this.editor.getSession().getValue()) {
      return;
    }

    this.skipChangePropagation = true;
    this.editor.getSession().setValue(this.args.content || "");
    this.skipChangePropagation = false;

    const token = WAITER.beginAsync();
    this.editor.renderer.once("afterRender", () => WAITER.endAsync(token));

    return () => WAITER.endAsync(token);
  });

  constructor() {
    super(...arguments);

    loadAce().then((ace) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.ace = ace;
      this.isLoading = false;
    });

    this.appEvents.on("ace:resize", this.resize);
    window.addEventListener("resize", this.resize);
    this._darkModeListener = window.matchMedia("(prefers-color-scheme: dark)");
    this._darkModeListener.addEventListener("change", this.setAceTheme);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.editor?.destroy();

    this._darkModeListener?.removeEventListener("change", this.setAceTheme);
    window.removeEventListener("resize", this.resize);
    this.appEvents.off("ace:resize", this.resize);
  }

  @bind
  setupAce(element) {
    if (this.args.htmlPlaceholder) {
      overridePlaceholder(this.ace);
    }

    this.ace.config.set("useWorker", false);

    this.editor = this.ace.edit(element);
    this.editor.setShowPrintMargin(false);
    this.editor.setOptions({
      fontSize: "14px",
      placeholder: this.args.placeholder,
    });

    const session = this.editor.getSession();
    session.setMode(`ace/mode/${this.mode}`);

    this.editor.on("change", () => {
      if (!this.skipChangePropagation) {
        this.args.onChange?.(session.getValue());
      }
    });

    if (this.args.save) {
      this.editor.commands.addCommand({
        name: "save",
        exec: () => this.args.save(),
        bindKey: { mac: "cmd-s", win: "ctrl-s" },
      });
    }
    if (this.args.submit) {
      this.editor.commands.addCommand({
        name: "submit",
        exec: () => this.args.submit(),
        bindKey: { mac: "cmd-enter", win: "ctrl-enter" },
      });
    }

    this.editor.on("blur", () => this.warnSCSSDeprecations());

    this.editor.$blockScrolling = Infinity;
    this.editor.renderer.setScrollMargin(10, 10);

    if (isTesting()) {
      element.aceEditor = this.editor;
    }

    this.changeDisabledState();
    this.warnSCSSDeprecations();

    if (this.autofocus) {
      this.focus();
    }

    this.setAceTheme();
  }

  get mode() {
    return this.args.mode || "css";
  }

  @bind
  editorIdChanged() {
    if (this.autofocus) {
      this.focus();
    }
  }

  @bind
  modeChanged() {
    this.editor?.getSession().setMode(`ace/mode/${this.mode}`);
  }

  @bind
  placeholderChanged() {
    this.editor?.setOptions({ placeholder: this.args.placeholder });
  }

  @bind
  changeDisabledState() {
    this.editor?.setOptions({
      readOnly: this.args.disabled,
      highlightActiveLine: !this.args.disabled,
      highlightGutterLine: !this.args.disabled,
    });

    this.editor?.container.parentNode.parentNode.setAttribute(
      "data-disabled",
      !!this.args.disabled
    );
  }

  warnSCSSDeprecations() {
    if (
      this.mode !== "scss" ||
      this.args.editorId.startsWith("color_definitions") ||
      !this.editor
    ) {
      return;
    }

    let warnings = this.args.content
      .split("\n")
      .map((line, row) => {
        if (line.match(COLOR_VARS_REGEX)) {
          return {
            row,
            column: 0,
            text: i18n("admin.customize.theme.scss_warning_inline"),
            type: "warning",
          };
        }
      })
      .filter(Boolean);

    this.editor.getSession().setAnnotations(warnings);

    this.args.setWarning?.(
      warnings.length
        ? i18n("admin.customize.theme.scss_color_variables_warning")
        : false
    );
  }

  @bind
  setAceTheme() {
    const schemeType = getComputedStyle(document.body)
      .getPropertyValue("--scheme-type")
      .trim();
    const aceTheme = schemeType === "dark" ? "chaos" : "chrome";

    this.editor.setTheme(`ace/theme/${aceTheme}`);
  }

  @bind
  resize() {
    this.editor?.resize();
  }

  @bind
  focus() {
    if (this.editor) {
      this.editor.focus();
      this.editor.navigateFileEnd();
    }
  }

  <template>
    <div class="ace-wrapper">
      <ConditionalLoadingSpinner @condition={{this.isLoading}} @size="small">
        <div
          {{didInsert this.setupAce}}
          {{this.setContent}}
          {{didUpdate this.editorIdChanged @editorId}}
          {{didUpdate this.modeChanged @mode}}
          {{didUpdate this.placeholderChanged @placeholder}}
          {{didUpdate this.changeDisabledState @disabled}}
          class="ace"
          ...attributes
        >
        </div>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
