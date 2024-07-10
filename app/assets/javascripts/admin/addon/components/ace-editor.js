import Component from "@ember/component";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import loadAce from "discourse/lib/load-ace-editor";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

const COLOR_VARS_REGEX =
  /\$(primary|secondary|tertiary|quaternary|header_background|header_primary|highlight|danger|success|love)(\s|;|-(low|medium|high))/g;

@classNames("ace-wrapper")
export default class AceEditor extends Component {
  isLoading = true;
  mode = "css";
  disabled = false;
  htmlPlaceholder = false;
  _editor = null;
  _skipContentChangeEvent = null;

  @observes("editorId")
  editorIdChanged() {
    if (this.autofocus) {
      this.send("focus");
    }
  }

  didRender() {
    super.didRender(...arguments);
    this._skipContentChangeEvent = false;
  }

  @observes("content")
  contentChanged() {
    const content = this.content || "";
    if (this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setValue(content);
    }
  }

  @observes("mode")
  modeChanged() {
    if (this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setMode("ace/mode/" + this.mode);
    }
  }

  @observes("placeholder")
  placeholderChanged() {
    if (this._editor) {
      this._editor.setOptions({
        placeholder: this.placeholder,
      });
    }
  }

  @observes("disabled")
  disabledStateChanged() {
    this.changeDisabledState();
  }

  changeDisabledState() {
    const editor = this._editor;
    if (editor) {
      const disabled = this.disabled;
      editor.setOptions({
        readOnly: disabled,
        highlightActiveLine: !disabled,
        highlightGutterLine: !disabled,
      });
      editor.container.parentNode.setAttribute("data-disabled", disabled);
    }
  }

  @on("willDestroyElement")
  _destroyEditor() {
    if (this._editor) {
      this._editor.destroy();
      this._editor = null;
    }

    this.appEvents.off("ace:resize", this.resize);
    window.removeEventListener("resize", this.resize);
  }

  @action
  resize() {
    if (this._editor) {
      this._editor.resize();
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.setup();
  }

  async setup() {
    const ace = await loadAce();

    this.set("isLoading", false);

    next(() => {
      if (this.htmlPlaceholder) {
        this._overridePlaceholder(ace);
      }

      ace.config.set("useWorker", false);

      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }
      const aceElement = this.element.querySelector(".ace");
      const editor = ace.edit(aceElement);
      editor.setShowPrintMargin(false);
      editor.setOptions({
        fontSize: "14px",
        placeholder: this.placeholder,
      });
      editor.getSession().setMode("ace/mode/" + this.mode);
      editor.on("change", () => {
        this._skipContentChangeEvent = true;
        this.set("content", editor.getSession().getValue());
      });
      if (this.save) {
        editor.commands.addCommand({
          name: "save",
          exec: () => {
            this.save();
          },
          bindKey: { mac: "cmd-s", win: "ctrl-s" },
        });
      }

      editor.on("blur", () => {
        this.warnSCSSDeprecations();
      });

      editor.$blockScrolling = Infinity;
      editor.renderer.setScrollMargin(10, 10);

      this.element.setAttribute("data-editor", editor);
      this._editor = editor;
      this.changeDisabledState();
      this.warnSCSSDeprecations();

      window.addEventListener("resize", this.resize);

      this.appEvents.on("ace:resize", this.resize);

      if (this.autofocus) {
        this.send("focus");
      }

      this.setAceTheme();

      this._darkModeListener = window.matchMedia(
        "(prefers-color-scheme: dark)"
      );
      this._darkModeListener.addListener(this.setAceTheme);
    });
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this._darkModeListener?.removeListener(this.setAceTheme);
    window.addEventListener("resize", () => {
      this.appEvents.trigger("ace:resize");
    });
  }

  get aceTheme() {
    const schemeType = getComputedStyle(document.body)
      .getPropertyValue("--scheme-type")
      .trim();

    return schemeType === "dark" ? "chaos" : "chrome";
  }

  @bind
  setAceTheme() {
    this._editor.setTheme(`ace/theme/${this.aceTheme}`);
  }

  warnSCSSDeprecations() {
    if (
      this.mode !== "scss" ||
      this.editorId.startsWith("color_definitions") ||
      !this._editor
    ) {
      return;
    }

    let warnings = this.content
      .split("\n")
      .map((line, row) => {
        if (line.match(COLOR_VARS_REGEX)) {
          return {
            row,
            column: 0,
            text: I18n.t("admin.customize.theme.scss_warning_inline"),
            type: "warning",
          };
        }
      })
      .filter(Boolean);

    this._editor.getSession().setAnnotations(warnings);

    this.setWarning?.(
      warnings.length
        ? I18n.t("admin.customize.theme.scss_color_variables_warning")
        : false
    );
  }

  @action
  focus() {
    if (this._editor) {
      this._editor.focus();
      this._editor.navigateFileEnd();
    }
  }

  _overridePlaceholder(ace) {
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
}
