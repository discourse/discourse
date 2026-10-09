import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const MAX_RETENTION_DAYS = 36500;

export default class AiLogRetentionModal extends Component {
  @cached
  get formData() {
    return {
      detailed_days: this.args.model.retention.detailed_days,
      summary_days: this.args.model.retention.summary_days,
    };
  }

  get formattedStorage() {
    const bytes = Number(this.args.model.storage?.total_bytes || 0);
    if (bytes < 1024) {
      return `${bytes} B`;
    }

    const units = ["KB", "MB", "GB", "TB"];
    let value = bytes / 1024;
    let unit = units[0];
    for (let index = 1; value >= 1024 && index < units.length; index++) {
      value /= 1024;
      unit = units[index];
    }
    return `${value.toFixed(1)} ${unit}`;
  }

  lifecycle(data) {
    const detailed = Number(data.detailed_days || 0);
    const summary = Number(data.summary_days || 0);

    if (detailed === 0 && summary === 0) {
      return i18n("discourse_ai.logs.retention.lifecycle.complete_forever");
    }
    if (detailed === 0) {
      return i18n("discourse_ai.logs.retention.lifecycle.detail_until_delete", {
        summary,
      });
    }
    if (summary === 0) {
      return i18n("discourse_ai.logs.retention.lifecycle.summary_forever", {
        detailed,
      });
    }
    return i18n("discourse_ai.logs.retention.lifecycle.finite", {
      detailed,
      summary,
    });
  }

  @action
  retentionPreview(data) {
    return this.lifecycle(data);
  }

  @action
  isShortening(data) {
    const cutoff = (retention) => {
      const summary = Number(retention.summary_days);
      const detailed = Number(retention.detailed_days);
      const summaryCutoff = summary > 0 ? summary : Infinity;

      return {
        summary: summaryCutoff,
        detailed: detailed > 0 ? detailed : summaryCutoff,
      };
    };
    const current = cutoff(this.args.model.retention);
    const proposed = cutoff(data);

    return (
      proposed.detailed < current.detailed || proposed.summary < current.summary
    );
  }

  @action
  validate(data, { addError, removeError }) {
    const detailed = Number(data.detailed_days);
    const summary = Number(data.summary_days);

    if (
      Number.isFinite(detailed) &&
      (!Number.isInteger(detailed) ||
        detailed < 0 ||
        detailed > MAX_RETENTION_DAYS)
    ) {
      addError("detailed_days", {
        title: i18n("discourse_ai.logs.retention.detailed_title"),
        message: i18n("discourse_ai.logs.retention.valid_range", {
          max: MAX_RETENTION_DAYS,
        }),
      });
    } else {
      removeError("detailed_days");
    }

    if (
      Number.isFinite(summary) &&
      (!Number.isInteger(summary) ||
        summary < 0 ||
        summary > MAX_RETENTION_DAYS)
    ) {
      addError("summary_days", {
        title: i18n("discourse_ai.logs.retention.summary_title"),
        message: i18n("discourse_ai.logs.retention.valid_range", {
          max: MAX_RETENTION_DAYS,
        }),
      });
    } else if (detailed > 0 && summary > 0 && summary < detailed) {
      addError("summary_days", {
        title: i18n("discourse_ai.logs.retention.summary_title"),
        message: i18n("discourse_ai.logs.retention.invalid_order"),
      });
    } else {
      removeError("summary_days");
    }
  }

  @action
  async save(data) {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-ai/ai-logs/retention.json",
        {
          type: "PUT",
          data: {
            detailed_days: Number(data.detailed_days),
            summary_days: Number(data.summary_days),
          },
        }
      );
      this.args.model.onSave(result.retention);
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="ai-log-retention-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.logs.retention.title"}}
    >
      <:body>
        <div
          aria-label={{i18n "discourse_ai.logs.retention.lifecycle_label"}}
          class="ai-log-retention-modal__lifecycle"
          role="img"
        >
          <span>{{i18n "discourse_ai.logs.retention.detailed_stage"}}</span>
          <span
            aria-hidden="true"
            class="ai-log-retention-modal__lifecycle-arrow"
          >→</span>
          <span>{{i18n "discourse_ai.logs.retention.summary_stage"}}</span>
          <span
            aria-hidden="true"
            class="ai-log-retention-modal__lifecycle-arrow"
          >→</span>
          <span>{{i18n "discourse_ai.logs.retention.deleted_stage"}}</span>
        </div>
        <p class="ai-log-retention-modal__hint">
          {{i18n "discourse_ai.logs.retention.hint"}}
        </p>

        <Form
          @data={{this.formData}}
          @onSubmit={{this.save}}
          @validate={{this.validate}}
          as |form data|
        >
          <form.Field
            @description={{i18n "discourse_ai.logs.retention.detailed_help"}}
            @format="large"
            @name="detailed_days"
            @title={{i18n "discourse_ai.logs.retention.detailed_title"}}
            @type="input-number"
            @validation="required|number"
            as |field|
          >
            <field.Control max={{MAX_RETENTION_DAYS}} min="0" step="1" />
          </form.Field>

          <form.Field
            @description={{i18n "discourse_ai.logs.retention.summary_help"}}
            @format="large"
            @name="summary_days"
            @title={{i18n "discourse_ai.logs.retention.summary_title"}}
            @type="input-number"
            @validation="required|number"
            as |field|
          >
            <field.Control max={{MAX_RETENTION_DAYS}} min="0" step="1" />
          </form.Field>

          <p class="ai-log-retention-modal__preview">
            {{this.retentionPreview data}}
          </p>
          {{#if (this.isShortening data)}}
            <div class="alert alert-warning">
              {{i18n "discourse_ai.logs.retention.destructive_warning"}}
            </div>
          {{/if}}

          <form.Submit
            class="btn-primary"
            @label="discourse_ai.logs.retention.save"
          />
        </Form>

        <p class="ai-log-retention-modal__meta">
          {{i18n "discourse_ai.logs.retention.meta" size=this.formattedStorage}}
        </p>
      </:body>
    </DModal>
  </template>
}
