import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import Field from "./field";

const PARAM_SCHEMA = { type: "string", ui: { expression: true } };

export default class QueryParams extends Component {
  get params() {
    const id = parseInt(this.args.configuration?.query_id, 10);
    const query = this.args.metadata?.queries?.find((q) => q.id === id) || null;

    return (query?.params ?? []).filter((p) => !p.internal);
  }

  get paramsConfiguration() {
    return this.args.configuration?.[this.args.fieldName] || {};
  }

  <template>
    {{#if this.params.length}}
      <@form.Section @title={{@label}}>
        <@form.Object @name={{@fieldName}} as |object|>
          {{#each this.params key="identifier" as |param|}}
            <Field
              @form={{object}}
              @formApi={{@formApi}}
              @fieldName={{param.identifier}}
              @formApiPath={{concat @fieldName "." param.identifier}}
              @configuration={{this.paramsConfiguration}}
              @label={{param.identifier}}
              @schema={{PARAM_SCHEMA}}
            />
          {{/each}}
        </@form.Object>
      </@form.Section>
    {{/if}}
  </template>
}
