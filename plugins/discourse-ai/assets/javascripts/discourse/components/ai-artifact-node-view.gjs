import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiArtifactOptionsModal from "./modal/ai-artifact-options-modal";

function metadataPath({ share, id, version }) {
  if (share) {
    return `/discourse-ai/ai-bot/artifact-shares/${encodeURIComponent(share)}/metadata.json`;
  }

  return `/discourse-ai/ai-bot/artifacts/${encodeURIComponent(id)}/metadata.json${version ? `?version=${encodeURIComponent(version)}` : ""}`;
}

export default class AiArtifactNodeView extends Component {
  @tracked title;

  #destroyed = false;
  #identity;
  #request = 0;

  constructor() {
    super(...arguments);
    this.#identity = metadataPath(this.args.node.attrs);
    this.args.onSetup?.(this);
    this.#loadTitle(this.#identity);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#destroyed = true;
    this.#request++;
  }

  get displayTitle() {
    return this.title || i18n("discourse_ai.ai_artifact.editor.title");
  }

  get optionSummary() {
    const { autorun, height, seamless } = this.args.node.attrs;
    const defaultValue = i18n("discourse_ai.ai_artifact.editor.default");
    return [
      {
        name: "autorun",
        text: i18n("discourse_ai.ai_artifact.editor.summary_autorun", {
          value: this.#optionValue(autorun),
        }),
      },
      {
        name: "height",
        text: i18n("discourse_ai.ai_artifact.editor.summary_height", {
          value: height
            ? i18n("discourse_ai.ai_artifact.editor.summary_height_value", {
                height,
              })
            : defaultValue,
        }),
      },
      {
        name: "seamless",
        text: i18n("discourse_ai.ai_artifact.editor.summary_seamless", {
          value: this.#optionValue(seamless),
        }),
      },
    ];
  }

  @action
  openOptions() {
    const { node, view, getPos, pluginParams } = this.args;
    pluginParams.getContext().modal.show(AiArtifactOptionsModal, {
      model: {
        attrs: { ...node.attrs },
        siteSettings: pluginParams.getContext().siteSettings,
        onApply: (attrs) => {
          const pos = getPos();
          if (
            pos === undefined ||
            !view.state.doc.nodeAt(pos)?.sameMarkup(node)
          ) {
            return;
          }

          const tr = view.state.tr.setNodeMarkup(pos, null, attrs);
          tr.setSelection(
            pluginParams.pmState.NodeSelection.create(tr.doc, pos)
          );
          view.dispatch(tr);
        },
        restoreFocus: () => next(() => !view.isDestroyed && view.focus()),
      },
    });
  }

  update(node) {
    const identity = metadataPath(node.attrs);
    if (identity !== this.#identity) {
      this.#identity = identity;
      this.title = null;
      this.#loadTitle(identity);
    }
  }

  stopEvent(event) {
    return event.target instanceof Element && !!event.target.closest("button");
  }

  #loadTitle(identity) {
    const request = ++this.#request;
    ajax(identity)
      .then(({ name }) => {
        if (!this.#destroyed && request === this.#request) {
          this.title = typeof name === "string" ? name : null;
        }
      })
      .catch(() => {
        if (!this.#destroyed && request === this.#request) {
          this.title = null;
        }
      });
  }

  #optionValue(value) {
    return i18n(
      `discourse_ai.ai_artifact.editor.${
        value == null
          ? "default"
          : [true, "true", "1"].includes(value)
            ? "option_on"
            : "option_off"
      }`
    );
  }

  <template>
    <div class="composer-ai-artifact" contenteditable="false" ...attributes>
      <div class="composer-ai-artifact__content">
        <span class="composer-ai-artifact__title">{{dIcon
            "code"
          }}{{this.displayTitle}}</span>
        <div class="composer-ai-artifact__options">
          {{#each this.optionSummary as |option|}}
            <span data-option={{option.name}}>{{option.text}}</span>
          {{/each}}
        </div>
      </div>
      <DButton
        class="btn-flat composer-ai-artifact__edit"
        @action={{this.openOptions}}
        @icon="pencil"
        @label="discourse_ai.ai_artifact.editor.edit_options"
      />
    </div>
  </template>
}
