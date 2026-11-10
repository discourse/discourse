import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import I18n, { i18n } from "discourse-i18n";

const FEATURE_USAGE_TYPES = new Set([
  "ai_bot",
  "ai_helper",
  "ai_image_caption",
  "ai_summarization",
  "ai_embeddings_semantic_search",
]);

const RECORD_USAGE_ROUTES = {
  ai_agent: { route: "adminPlugins.show.discourse-ai-agents.edit" },
  automation: {
    route: "adminPlugins.show.automation.edit",
    parentModel: "automation",
  },
  vision_delegate: { route: "adminPlugins.show.discourse-ai-llms.edit" },
};

export function usageRoute(usage) {
  if (!usage?.type) {
    return null;
  }

  if (FEATURE_USAGE_TYPES.has(usage.type)) {
    return usage.id === null || usage.id === undefined
      ? null
      : {
          route: "adminPlugins.show.discourse-ai-features.edit",
          models: [usage.id],
        };
  }

  if (usage.type === "ai_spam") {
    return { route: "adminPlugins.show.discourse-ai-spam" };
  }

  const target = RECORD_USAGE_ROUTES[usage.type];

  if (!target || usage.id === null || usage.id === undefined) {
    return null;
  }

  return {
    route: target.route,
    models: target.parentModel ? [target.parentModel, usage.id] : [usage.id],
  };
}

function localizeUsage(usage) {
  if (!usage?.type) {
    return usage?.name || "";
  }

  const key = `discourse_ai.llms.usage.${usage.type}`;
  if (I18n.lookup(key, { ignoreMissing: true })) {
    return i18n(key, { agent: usage.name });
  }

  return usage.name || usage.type;
}

class UsageItem extends Component {
  get target() {
    return usageRoute(this.args.usage);
  }

  get label() {
    return localizeUsage(this.args.usage);
  }

  <template>
    {{#if this.target}}
      {{#if this.target.models}}
        <LinkTo @models={{this.target.models}} @route={{this.target.route}}>
          {{this.label}}
        </LinkTo>
      {{else}}
        <LinkTo @route={{this.target.route}}>{{this.label}}</LinkTo>
      {{/if}}
    {{else}}
      {{this.label}}
    {{/if}}
  </template>
}

const AiLlmUsages = <template>
  {{#if @usages}}
    <ul class="ai-llm-list-editor__usages">
      {{#each @usages as |usage|}}
        <li><UsageItem @usage={{usage}} /></li>
      {{/each}}
    </ul>
  {{/if}}
</template>;

export default AiLlmUsages;
