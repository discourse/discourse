import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default class AiTranslationModelProgressDetailCard extends Component {
  @service languageNameLookup;

  get targetType() {
    return this.args.data.target_type;
  }

  get isTag() {
    return this.targetType === "tag";
  }

  get rows() {
    return (this.args.data.locales || []).map((locale) => {
      const denominator = Number(
        this.isTag ? locale.total_count : locale.eligible_count
      );
      const translated = Number(locale.translated_count) || 0;
      const percentage =
        denominator > 0
          ? Math.min(Math.round((translated / denominator) * 100), 100)
          : 0;

      return {
        ...locale,
        denominator,
        languageName: this.languageNameLookup.getLanguageName(locale.locale),
        percentage,
        progressStyle: trustHTML(`width: ${percentage}%`),
      };
    });
  }

  get showPending() {
    return (
      this.rows.length > 0 &&
      this.rows.every(({ pending_count }) => pending_count !== null)
    );
  }

  get denominatorLabel() {
    return i18n(
      `discourse_ai.translations.model_progress.detail.columns.${
        this.isTag ? "total" : "eligible"
      }`
    );
  }

  get eligibleHelp() {
    return i18n(
      "discourse_ai.translations.model_progress.detail.eligible_help"
    );
  }

  get pendingHelp() {
    return i18n("discourse_ai.translations.model_progress.detail.pending_help");
  }

  progressLabel(row) {
    return i18n(
      "discourse_ai.translations.model_progress.detail.progress_label",
      {
        translated: row.translated_count,
        total: row.denominator,
        language: row.languageName,
      }
    );
  }

  <template>
    <div class="ai-translation-model-progress-detail">
      {{#if this.rows.length}}
        <table class="d-table ai-translation-locale-progress">
          <thead class="d-table__header">
            <tr>
              <th class="ai-translation-locale-progress__locale-header">
                {{i18n
                  "discourse_ai.translations.model_progress.detail.columns.locale"
                }}
              </th>
              <th class="ai-translation-locale-progress__translated-header">
                {{i18n
                  "discourse_ai.translations.model_progress.detail.columns.translated"
                }}
              </th>
              {{#if this.showPending}}
                <th class="ai-translation-locale-progress__pending-header">
                  <DTooltip
                    @icon="circle-question"
                    @content={{this.pendingHelp}}
                    class="ai-translation-locale-progress__help"
                  />
                  <span>
                    {{i18n
                      "discourse_ai.translations.model_progress.detail.columns.pending"
                    }}
                  </span>
                </th>
              {{/if}}
              <th class="ai-translation-locale-progress__denominator-header">
                {{#unless this.isTag}}
                  <DTooltip
                    @icon="circle-question"
                    @content={{this.eligibleHelp}}
                    class="ai-translation-locale-progress__help"
                  />
                {{/unless}}
                <span>{{this.denominatorLabel}}</span>
              </th>
              <th class="ai-translation-locale-progress__progress-header">
                {{i18n
                  "discourse_ai.translations.model_progress.detail.columns.progress"
                }}
              </th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.rows as |row|}}
              <tr class="d-table__row ai-translation-locale-progress__row">
                <td
                  class="d-table__cell --overview ai-translation-locale-progress__locale"
                >
                  <span class="ai-translation-locale-progress__locale-name">
                    {{row.languageName}}
                  </span>
                  <span class="ai-translation-locale-progress__locale-code">
                    {{row.locale}}
                  </span>
                </td>
                <td
                  class="d-table__cell --detail ai-translation-locale-progress__translated"
                >
                  <span class="d-table__mobile-label">
                    {{i18n
                      "discourse_ai.translations.model_progress.detail.columns.translated"
                    }}
                  </span>
                  <span
                    class="ai-translation-locale-progress__translated-value"
                  >
                    {{row.translated_count}}
                  </span>
                </td>
                {{#if this.showPending}}
                  <td
                    class="d-table__cell --detail ai-translation-locale-progress__pending"
                  >
                    <span class="d-table__mobile-label">
                      {{i18n
                        "discourse_ai.translations.model_progress.detail.columns.pending"
                      }}
                    </span>
                    <span class="ai-translation-locale-progress__pending-value">
                      {{row.pending_count}}
                    </span>
                  </td>
                {{/if}}
                <td
                  class="d-table__cell --detail ai-translation-locale-progress__denominator"
                >
                  <span class="d-table__mobile-label">
                    {{this.denominatorLabel}}
                  </span>
                  <span
                    class="ai-translation-locale-progress__denominator-value"
                  >
                    {{row.denominator}}
                  </span>
                </td>
                <td
                  class="d-table__cell --detail ai-translation-locale-progress__progress"
                >
                  <span class="d-table__mobile-label">
                    {{i18n
                      "discourse_ai.translations.model_progress.detail.columns.progress"
                    }}
                  </span>
                  <div
                    class="ai-translation-progress-bar"
                    role="progressbar"
                    aria-label={{this.progressLabel row}}
                    aria-valuenow={{row.percentage}}
                    aria-valuemin="0"
                    aria-valuemax="100"
                  >
                    <span
                      class="ai-translation-progress-bar__fill"
                      style={{row.progressStyle}}
                    ></span>
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="ai-translation-model-progress-detail__empty">
          {{i18n "discourse_ai.translations.model_progress.detail.empty"}}
        </p>
      {{/if}}
    </div>
  </template>
}
