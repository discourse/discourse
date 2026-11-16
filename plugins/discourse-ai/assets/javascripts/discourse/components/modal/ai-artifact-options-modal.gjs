import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const SHARE_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const DECIMAL_PATTERN = /^[0-9]{1,19}$/;
const HEIGHT_PATTERN = /^[1-9][0-9]{0,3}$/;

function shareKey(reference) {
  if (SHARE_PATTERN.test(reference)) {
    return reference;
  }

  try {
    const url = new URL(reference, window.location.href);
    const prefix = getURL("/discourse-ai/ai-bot/artifact-shares/");
    if (
      url.origin === window.location.origin &&
      !url.search &&
      !url.hash &&
      url.pathname.startsWith(prefix)
    ) {
      const key = url.pathname.slice(prefix.length);
      if (SHARE_PATTERN.test(key)) {
        return key;
      }
    }
  } catch {
    return;
  }
}

function positiveDecimal(value) {
  return DECIMAL_PATTERN.test(value) && value.replace(/^0+/, "") !== "";
}

function normalizedDecimal(value) {
  return value.replace(/^0+/, "");
}

export default class AiArtifactOptionsModal extends Component {
  get isShare() {
    return this.args.model.attrs.share != null;
  }

  get formData() {
    const { share, id, version, autorun, height, seamless } =
      this.args.model.attrs;
    return {
      reference: share ?? id,
      version: version ?? "",
      autorun: autorun ?? "default",
      height: height ?? "",
      seamless:
        seamless == null
          ? "default"
          : ["true", "1"].includes(seamless)
            ? "true"
            : "false",
    };
  }

  get policyDescription() {
    const security = this.args.model.siteSettings.ai_artifact_security;
    if (security === "strict" || security === "lax") {
      return i18n(`discourse_ai.ai_artifact.editor.autorun_${security}`);
    }
    return i18n("discourse_ai.ai_artifact.editor.autorun_default_description");
  }

  @action
  validate(data, { addError, removeError }) {
    for (const name of ["reference", "version", "height"]) {
      removeError(name);
    }

    const invalid = (name, message) =>
      addError(name, {
        title: i18n(`discourse_ai.ai_artifact.editor.${name}`),
        message: i18n(`discourse_ai.ai_artifact.editor.${message}`),
      });

    if (
      this.isShare
        ? !shareKey(data.reference)
        : !positiveDecimal(data.reference)
    ) {
      invalid("reference", this.isShare ? "invalid_share" : "invalid_source");
    }
    if (!this.isShare && data.version && !positiveDecimal(data.version)) {
      invalid("version", "invalid_version");
    }
    if (
      data.height &&
      data.height !== this.formData.height &&
      (!HEIGHT_PATTERN.test(data.height) || Number(data.height) > 2000)
    ) {
      invalid("height", "invalid_height");
    }
  }

  @action
  apply(data) {
    const original = this.args.model.attrs;
    const attrs = {
      ...original,
      share: this.isShare ? shareKey(data.reference) : null,
      id: this.isShare ? null : normalizedDecimal(data.reference),
      version: this.isShare
        ? null
        : data.version
          ? normalizedDecimal(data.version)
          : null,
      autorun: data.autorun === "default" ? null : data.autorun,
      height: data.height || null,
      seamless:
        data.seamless === this.formData.seamless
          ? original.seamless
          : data.seamless === "default"
            ? null
            : data.seamless,
    };

    if (Object.keys(attrs).some((key) => attrs[key] !== original[key])) {
      this.args.model.onApply(attrs);
    }
    this.close();
  }

  @action
  close() {
    this.args.closeModal();
    this.args.model.restoreFocus();
  }

  <template>
    <DModal
      class="ai-artifact-options-modal"
      @closeModal={{this.close}}
      @title={{i18n "discourse_ai.ai_artifact.editor.edit_options"}}
    >
      <Form
        @data={{this.formData}}
        @onSubmit={{this.apply}}
        @validate={{this.validate}}
        as |form|
      >
        <form.Field
          @description={{i18n
            (if
              this.isShare
              "discourse_ai.ai_artifact.editor.share_reference_description"
              "discourse_ai.ai_artifact.editor.source_reference_description"
            )
          }}
          @format="full"
          @name="reference"
          @title={{i18n "discourse_ai.ai_artifact.editor.reference"}}
          @type="input"
          @validation="required"
          as |field|
        ><field.Control autofocus="autofocus" /></form.Field>

        {{#unless this.isShare}}
          <form.Field
            @description={{i18n
              "discourse_ai.ai_artifact.editor.version_description"
            }}
            @name="version"
            @title={{i18n "discourse_ai.ai_artifact.editor.version"}}
            @type="input"
            as |field|
          ><field.Control inputmode="numeric" /></form.Field>
        {{/unless}}

        <form.Field
          class="ai-artifact-options-modal__policy"
          @description={{this.policyDescription}}
          @name="autorun"
          @title={{i18n "discourse_ai.ai_artifact.editor.autorun"}}
          @type="select"
          as |field|
        >
          <field.Control as |select|>
            <select.Option @value="default">{{i18n
                "discourse_ai.ai_artifact.editor.default"
              }}</select.Option>
            <select.Option @value="true">{{i18n
                "discourse_ai.ai_artifact.editor.option_on"
              }}</select.Option>
            <select.Option @value="false">{{i18n
                "discourse_ai.ai_artifact.editor.option_off"
              }}</select.Option>
          </field.Control>
        </form.Field>

        <form.Field
          @description={{i18n
            "discourse_ai.ai_artifact.editor.height_description"
          }}
          @name="height"
          @title={{i18n "discourse_ai.ai_artifact.editor.height"}}
          @type="input"
          as |field|
        ><field.Control inputmode="numeric" /></form.Field>

        <form.Field
          @description={{i18n
            "discourse_ai.ai_artifact.editor.seamless_description"
          }}
          @name="seamless"
          @title={{i18n "discourse_ai.ai_artifact.editor.seamless"}}
          @type="select"
          as |field|
        >
          <field.Control as |select|>
            <select.Option @value="default">{{i18n
                "discourse_ai.ai_artifact.editor.default"
              }}</select.Option>
            <select.Option @value="true">{{i18n
                "discourse_ai.ai_artifact.editor.option_on"
              }}</select.Option>
            <select.Option @value="false">{{i18n
                "discourse_ai.ai_artifact.editor.option_off"
              }}</select.Option>
          </field.Control>
        </form.Field>

        <form.Actions>
          <DButton
            class="btn-transparent ai-artifact-options-modal__cancel"
            @action={{this.close}}
            @label="cancel"
          />
          <form.Submit
            class="ai-artifact-options-modal__apply"
            @label="discourse_ai.ai_artifact.editor.apply"
          />
        </form.Actions>
      </Form>
    </DModal>
  </template>
}
