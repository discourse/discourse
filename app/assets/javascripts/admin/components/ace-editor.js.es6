import loadScript from "discourse/lib/load-script";
import { observes } from "ember-addons/ember-computed-decorators";

const LOAD_ASYNC = !Ember.testing;

export default Ember.Component.extend({
  mode: "css",
  classNames: ["ace-wrapper"],
  _editor: null,
  _skipContentChangeEvent: null,
  disabled: false,

  @observes("editorId")
  editorIdChanged() {
    if (this.get("autofocus")) {
      this.send("focus");
    }
  },

  @observes("content")
  contentChanged() {
    if (this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setValue(this.get("content"));
    }
  },

  @observes("mode")
  modeChanged() {
    if (LOAD_ASYNC && this._editor && !this._skipContentChangeEvent) {
      this._editor.getSession().setMode("ace/mode/" + this.get("mode"));
    }
  },

  @observes("disabled")
  disabledStateChanged() {
    this.changeDisabledState();
  },

  changeDisabledState() {
    const editor = this._editor;
    if (editor) {
      const disabled = this.get("disabled");
      editor.setOptions({
        readOnly: disabled,
        highlightActiveLine: !disabled,
        highlightGutterLine: !disabled
      });
      editor.container.parentNode.setAttribute("data-disabled", disabled);
    }
  },

  _destroyEditor: function() {
    if (this._editor) {
      this._editor.destroy();
      this._editor = null;
    }
    if (this.appEvents) {
      // xxx: don't run during qunit tests
      this.appEvents.off("ace:resize", this, this.resize);
    }

    $(window).off("ace:resize");
  }.on("willDestroyElement"),

  resize() {
    if (this._editor) {
      this._editor.resize();
    }
  },

  didInsertElement() {
    this._super();

    loadScript("/javascripts/ace/ace.js", { scriptTag: true }).then(() => {
      window.ace.require(["ace/ace"], loadedAce => {
        if (!this.element || this.isDestroying || this.isDestroyed) {
          return;
        }
        const editor = loadedAce.edit(this.$(".ace")[0]);

        if (LOAD_ASYNC) {
          editor.setTheme("ace/theme/chrome");
        }
        editor.setShowPrintMargin(false);
        editor.setOptions({ fontSize: "14px" });
        if (LOAD_ASYNC) {
          editor.getSession().setMode("ace/mode/" + this.get("mode"));
        }
        editor.on("change", () => {
          this._skipContentChangeEvent = true;
          this.set("content", editor.getSession().getValue());
          this._skipContentChangeEvent = false;
        });
        editor.$blockScrolling = Infinity;
        editor.renderer.setScrollMargin(10, 10);

        this.$().data("editor", editor);
        this._editor = editor;
        this.changeDisabledState();

        $(window)
          .off("ace:resize")
          .on("ace:resize", () => {
            this.appEvents.trigger("ace:resize");
          });

        if (this.appEvents) {
          // xxx: don't run during qunit tests
          this.appEvents.on("ace:resize", () => this.resize());
        }

        if (this.get("autofocus")) {
          this.send("focus");
        }
      });
    });
  },

  actions: {
    focus() {
      if (this._editor) {
        this._editor.focus();
        this._editor.navigateFileEnd();
      }
    }
  }
});
