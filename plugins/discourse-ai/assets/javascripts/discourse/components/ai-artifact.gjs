import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import htmlClass from "discourse/helpers/html-class";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import AiArtifactShare from "./ai-artifact-share";

export default class AiArtifactComponent extends Component {
  @service siteSettings;

  @tracked expanded = false;
  @tracked showingArtifact = false;

  constructor() {
    super(...arguments);
    this.keydownHandler = this.handleKeydown.bind(this);
    this.popStateHandler = this.handlePopState.bind(this);
    window.addEventListener("popstate", this.popStateHandler);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("keydown", this.keydownHandler);
    window.removeEventListener("popstate", this.popStateHandler);
  }

  get requireClickToRun() {
    if (this.showingArtifact) {
      return false;
    }

    if (this.siteSettings.ai_artifact_security === "strict") {
      return true;
    }

    if (this.siteSettings.ai_artifact_security === "hybrid") {
      const shouldAutorun =
        this.args.autorun === "true" ||
        this.args.autorun === true ||
        this.args.autorun === "1";

      return !shouldAutorun;
    }

    return this.siteSettings.ai_artifact_security !== "lax";
  }

  get hasShareKey() {
    return this.args.shareKey !== null && this.args.shareKey !== undefined;
  }

  get artifactIdentity() {
    if (this.hasShareKey) {
      return `share:${this.args.shareKey}`;
    }

    const version = String(this.args.artifactVersion ?? "").replace(/^0+/, "");
    return `artifact:${this.args.artifactId}:${version}`;
  }

  get artifactUrl() {
    if (this.hasShareKey) {
      if (!/^[A-Za-z0-9_-]{1,128}$/.test(this.args.shareKey)) {
        return;
      }

      return getURL(
        `/discourse-ai/ai-bot/artifact-shares/${encodeURIComponent(this.args.shareKey)}/forum`
      );
    }

    if (!/^[0-9]+$/.test(this.args.artifactId)) {
      return;
    }

    let url = getURL(`/discourse-ai/ai-bot/artifacts/${this.args.artifactId}`);

    const version = String(this.args.artifactVersion ?? "");
    if (version && !/^[0-9]+$/.test(version)) {
      return;
    }

    const normalizedVersion = version.replace(/^0+/, "");
    if (normalizedVersion) {
      url = `${url}/${encodeURIComponent(normalizedVersion)}`;
    }
    return url;
  }

  get wrapperClasses() {
    return `ai-artifact__wrapper ${
      this.expanded ? "ai-artifact__expanded" : ""
    } ${this.seamless ? "ai-artifact__seamless" : ""}`;
  }

  get heightStyle() {
    if (this.args.artifactHeight) {
      let height = parseInt(this.args.artifactHeight, 10);
      if (isNaN(height) || height <= 0) {
        height = 500; // default height if the provided value is invalid
      }

      if (height > 2000) {
        height = 2000; // cap the height to a maximum of 2000px
      }

      return trustHTML(`height: ${height}px;`);
    }
  }

  get seamless() {
    return (
      this.args.seamless === "true" ||
      this.args.seamless === true ||
      this.args.seamless === "1"
    );
  }

  get showFooter() {
    return !this.seamless && !this.requireClickToRun;
  }

  @action
  handleKeydown(event) {
    if (event.key === "Escape" || event.key === "Esc") {
      history.back();
    }
  }

  @action
  handlePopState(event) {
    const state = event.state;
    this.expanded = state?.artifactIdentity
      ? state.artifactIdentity === this.artifactIdentity
      : !this.hasShareKey &&
        this.args.artifactId != null &&
        state?.artifactId === this.args.artifactId;
    if (!this.expanded) {
      window.removeEventListener("keydown", this.keydownHandler);
    }
  }

  @action
  showArtifact() {
    this.showingArtifact = true;
  }

  @action
  toggleView() {
    if (!this.expanded) {
      window.history.pushState(
        {
          artifactId: this.args.artifactId,
          artifactIdentity: this.artifactIdentity,
        },
        "",
        window.location.href + "#artifact-fullscreen"
      );
      window.addEventListener("keydown", this.keydownHandler);
    } else {
      history.back();
    }
    this.expanded = !this.expanded;
  }

  @action
  setDataAttributes(element) {
    if (this.args.dataAttributes) {
      Object.entries(this.args.dataAttributes).forEach(([key, value]) => {
        element.setAttribute(key, value);
      });
    }
  }

  <template>
    {{#if this.expanded}}
      {{htmlClass "ai-artifact-expanded"}}
    {{/if}}
    <div class={{this.wrapperClasses}} style={{this.heightStyle}}>
      <div class="ai-artifact__panel--wrapper">
        <div class="ai-artifact__panel">
          <DButton
            class="btn-flat btn-icon-text"
            @action={{this.toggleView}}
            @icon="discourse-compress"
            @label="discourse_ai.ai_artifact.collapse_view_label"
          />
        </div>
      </div>
      {{#if this.requireClickToRun}}
        <div class="ai-artifact__click-to-run">
          <DButton
            class="btn btn-primary"
            @action={{this.showArtifact}}
            @icon="play"
            @label="discourse_ai.ai_artifact.click_to_run_label"
          />
        </div>
      {{else if this.artifactUrl}}
        <iframe
          frameborder="0"
          src={{this.artifactUrl}}
          title="AI Artifact"
          width="100%"
          {{didInsert this.setDataAttributes}}
        ></iframe>
      {{/if}}
      {{#if this.showFooter}}
        <div class="ai-artifact__footer">
          {{#unless this.hasShareKey}}
            <AiArtifactShare
              @artifactId={{@artifactId}}
              @artifactVersion={{@artifactVersion}}
            />
          {{/unless}}
          <DButton
            class="btn-transparent btn-icon-text ai-artifact__expand-button"
            @action={{this.toggleView}}
            @icon="discourse-expand"
            @label="discourse_ai.ai_artifact.expand_view_label"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
