import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

function compactTokenCount(value) {
  if (value < 1_000) {
    return I18n.toNumber(value, { precision: 0 });
  }

  const millions = value >= 999_500;
  const scaled = value / (millions ? 1_000_000 : 1_000);
  const roundedToOneDecimal = Math.round(scaled * 10) / 10;
  const precision =
    scaled < 10 && !Number.isInteger(roundedToOneDecimal) ? 1 : 0;
  const number = I18n.toNumber(scaled, { precision });

  return i18n(`number.short.${millions ? "millions" : "thousands"}`, {
    number,
  });
}

export default class AiLogRow extends Component {
  get status() {
    const log = this.args.log;
    if (["successful", "failed"].includes(log.outcome)) {
      return log.outcome;
    }

    return (log.response_status >= 200 && log.response_status <= 299) ||
      (log.response_status == null && Number(log.response_tokens || 0) > 0)
      ? "successful"
      : "failed";
  }

  get statusLabel() {
    return i18n(`discourse_ai.logs.${this.status}`);
  }

  get statusClass() {
    return this.status === "successful" ? "--success" : "--failed";
  }

  get statusIcon() {
    return this.status === "successful" ? "circle-check" : "circle-xmark";
  }

  get featureName() {
    return this.args.log.feature_name || "—";
  }

  get modelName() {
    return this.args.log.model_name || this.args.log.language_model || "—";
  }

  get tokenValues() {
    const { request_tokens: request, response_tokens: response } =
      this.args.log;

    return {
      request:
        request == null ? null : I18n.toNumber(request, { precision: 0 }),
      response:
        response == null ? null : I18n.toNumber(response, { precision: 0 }),
    };
  }

  get compactTokenValues() {
    const { request_tokens: request, response_tokens: response } =
      this.args.log;

    return {
      request: request == null ? "—" : compactTokenCount(request),
      response: response == null ? "—" : compactTokenCount(response),
    };
  }

  get tokensLabel() {
    const { request, response } = this.compactTokenValues;
    return request === "—" && response === "—"
      ? "—"
      : i18n("discourse_ai.logs.tokens_pair", { request, response });
  }

  get tokensAriaLabel() {
    const { request, response } = this.tokenValues;
    if (request == null && response == null) {
      return i18n("discourse_ai.logs.tokens_unavailable");
    }

    return i18n("discourse_ai.logs.tokens_aria", {
      request: request ?? i18n("discourse_ai.logs.unknown"),
      response: response ?? i18n("discourse_ai.logs.unknown"),
    });
  }

  get formattedDuration() {
    return this.args.log.duration_msecs == null
      ? "—"
      : i18n("discourse_ai.logs.detail.duration_seconds", {
          seconds: (this.args.log.duration_msecs / 1000).toFixed(1),
        });
  }

  get topicUrl() {
    return this.args.log.topic_id
      ? getURL(`/t/${this.args.log.topic_id}`)
      : null;
  }

  get postUrl() {
    return this.args.log.post_id ? getURL(`/p/${this.args.log.post_id}`) : null;
  }

  get hasContext() {
    return Boolean(this.topicUrl || this.postUrl);
  }

  <template>
    <tr class="d-table__row ai-logs__row" data-log-id={{@log.id}}>
      <td class="d-table__cell ai-logs__col-outcome">
        <div class="ai-logs__status-cell">
          <DTooltip @content={{this.statusLabel}}>
            <:trigger>
              {{dIcon
                this.statusIcon
                class=(dConcatClass "ai-logs__status-icon" this.statusClass)
                aria-label=this.statusLabel
              }}
            </:trigger>
          </DTooltip>

          {{#if @log.has_retries}}
            <DTooltip @content={{i18n "discourse_ai.logs.retried"}}>
              <:trigger>
                <span
                  class="ai-logs__flag"
                  role="img"
                  aria-label={{i18n "discourse_ai.logs.retried"}}
                >
                  {{dIcon "arrows-rotate"}}
                </span>
              </:trigger>
            </DTooltip>
          {{/if}}
        </div>
      </td>
      <td class="d-table__cell ai-logs__col-time">
        {{dAgeWithTooltip @log.created_at}}
      </td>
      <td class="d-table__cell ai-logs__col-request">
        <span class="ai-logs__feature" title={{this.featureName}}>
          {{this.featureName}}
        </span>
        <span class="ai-logs__model" title={{this.modelName}}>
          {{this.modelName}}
        </span>
      </td>
      <td class="d-table__cell ai-logs__col-user">
        {{#if @log.username}}
          <DUserLink
            @user={{@log}}
            class="ai-logs__user"
            title={{@log.username}}
          >
            {{dAvatar
              @log
              avatarTemplatePath="avatar_template"
              imageSize="tiny"
            }}
            <span>{{@log.username}}</span>
          </DUserLink>
        {{else}}
          <span class="ai-logs__unattributed">
            {{i18n "discourse_ai.logs.unattributed"}}
          </span>
        {{/if}}
      </td>
      <td class="d-table__cell ai-logs__col-duration">
        <span class="ai-logs__duration-value">{{this.formattedDuration}}</span>
        <span class="ai-logs__token-summary">
          <span aria-hidden="true" dir="ltr">{{this.tokensLabel}}</span>
          <span class="sr-only">{{this.tokensAriaLabel}}</span>
        </span>
      </td>
      <td class="d-table__cell ai-logs__col-context">
        <div class="ai-logs__context-links">
          {{#if this.topicUrl}}
            <a href={{this.topicUrl}}>
              {{i18n "discourse_ai.logs.topic_short" id=@log.topic_id}}
            </a>
          {{/if}}
          {{#if this.postUrl}}
            <a href={{this.postUrl}}>
              {{i18n "discourse_ai.logs.post_short" id=@log.post_id}}
            </a>
          {{/if}}
          {{#unless this.hasContext}}
            <span class="ai-logs__empty-value">—</span>
          {{/unless}}
        </div>
      </td>
      <td class="d-table__cell ai-logs__col-actions">
        <DButton
          class="btn-default btn-small"
          @action={{fn @onOpen @log.id}}
          @icon="far-file-lines"
          @title="discourse_ai.logs.view_details"
          @ariaLabel="discourse_ai.logs.view_details"
        />
      </td>
    </tr>
  </template>
}
