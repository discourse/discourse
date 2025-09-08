import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, eq, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import AiFeatureCard from "./ai-feature-card";

export default class AiFeaturesList extends Component {
  @service router;

  get sortedModules() {
    const modules = this.args.modules?.toArray() || this.args.modules;
    return [...(modules || [])].toSorted((a, b) =>
      (a.module_name || "").localeCompare(b.module_name || "")
    );
  }

  @action
  isSpamModule(aModule) {
    return aModule.module_name === "spam";
  }

  @action
  isAutomationModule(aModule) {
    return (
      aModule.module_name === "automation_reports" ||
      aModule.module_name === "automation_triage"
    );
  }

  @action
  featureName(feature, aModule) {
    if (this.isAutomationModule(aModule)) {
      return feature.name;
    } else {
      return i18n(
        `discourse_ai.features.${aModule.module_name}.${feature.name}`
      );
    }
  }

  @action
  transitionToAutomations() {
    this.router.transitionTo("/admin/plugins/automation/automation");
  }

  <template>
    <div class="ai-features-list">
      {{#each this.sortedModules as |module|}}
        <div class="ai-module" data-module-name={{module.module_name}}>
          <div class="ai-module__header">
            <div class="ai-module__module-title">
              <h3>{{i18n
                  (concat "discourse_ai.features." module.module_name ".name")
                }}</h3>
              {{#if (this.isSpamModule module)}}
                <DButton
                  class="edit"
                  @label="discourse_ai.features.edit"
                  @route="adminPlugins.show.discourse-ai-spam"
                />
              {{else if (this.isAutomationModule module)}}
                <DButton
                  class="edit"
                  @label="discourse_ai.features.edit"
                  @action={{this.transitionToAutomations}}
                />
              {{else}}
                <DButton
                  class="edit"
                  @label="discourse_ai.features.edit"
                  @route="adminPlugins.show.discourse-ai-features.edit"
                  @routeModels={{module.id}}
                />
              {{/if}}
            </div>
            <div>{{i18n
                (concat
                  "discourse_ai.features." module.module_name ".description"
                )
              }}</div>
          </div>

          <div class="admin-section-landing-wrapper ai-feature-cards">
            {{#if
              (and
                (this.isAutomationModule module) (eq module.features.length 0)
              )
            }}
              <div>{{i18n "discourse_ai.features.no_automations"}}</div>
            {{else}}
              {{#each module.features as |feature|}}
                <AiFeatureCard
                  @localizedFeatureName={{this.featureName feature module}}
                  @feature={{feature}}
                  @showGroups={{not (this.isSpamModule module)}}
                />
              {{/each}}
            {{/if}}
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
