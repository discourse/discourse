import Component from "@glimmer/component";
import { type TrustedHTML, trustHTML } from "@ember/template";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

interface DUserStatCommonArgs {
  /**
   * The translation key of the label. It receives the value as `count`, and its
   * markup is rendered.
   */
  label: string;

  /** The ID of an icon shown before the label. */
  icon?: string;

  /** The title of the value, shown on hover. */
  rawTitle?: string;
}

interface DUserStatNumberArgs extends DUserStatCommonArgs {
  /**
   * How to show the value: `number` (the default) as a compact number, and
   * `duration` as a short duration.
   */
  type?: "number" | "duration";

  /** The value of the stat. For the `duration` type, it is in seconds. */
  value?: number;
}

interface DUserStatStringArgs extends DUserStatCommonArgs {
  /** Shows the value as given, for a value the caller has already formatted. */
  type: "string";

  /** The value of the stat. */
  value?: number | string | TrustedHTML | null;
}

interface DUserStatSignature {
  Args: DUserStatNumberArgs | DUserStatStringArgs;
}

export default class DUserStat extends Component<DUserStatSignature> {
  get type() {
    return this.args.type ?? "number";
  }

  get isNumber() {
    return this.type === "number";
  }

  get isDuration() {
    return this.type === "duration";
  }

  /**
   * The value as a number, for the `number` and `duration` types.
   *
   * @returns The value, or `undefined` for the `string` type.
   */
  get numberValue() {
    return this.args.type === "string" ? undefined : this.args.value;
  }

  <template>
    <div class="user-stat">
      <span class="value" title={{@rawTitle}}>
        {{#if this.isNumber}}
          {{dNumber this.numberValue}}
        {{else if this.isDuration}}
          {{dFormatDuration this.numberValue}}
        {{else}}
          {{@value}}
        {{/if}}
      </span>
      <span class="label">
        {{#if @icon}}{{dIcon @icon}}{{/if}}
        {{trustHTML (i18n @label count=@value)}}
      </span>
    </div>
  </template>
}
