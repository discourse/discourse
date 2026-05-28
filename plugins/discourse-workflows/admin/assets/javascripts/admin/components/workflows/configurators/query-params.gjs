import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import Field from "./field";

const PARAM_SCHEMA = { type: "string", ui: { expression: true } };

export default class QueryParams extends Component {
  @service workflowsNodeTypes;

  @tracked _loadedQueries = null;

  constructor(owner, args) {
    super(owner, args);
    const identifier =
      args.nodeDefinition?.name || args.nodeDefinition?.identifier;
    if (identifier) {
      this.workflowsNodeTypes
        .loadNodeParameterOptions(
          identifier,
          "queries",
          args.nodeDefinition?.version,
          args.session?.nodeParameterOptionsContext({
            path: "query_id",
            currentNodeParameters: args.configuration || {},
          }) || {
            path: "query_id",
            currentNodeParameters: args.configuration || {},
          }
        )
        .then((queries) => {
          this._loadedQueries = queries;
        });
    }
  }

  get params() {
    const id = parseInt(this.args.configuration?.query_id, 10);
    const queries = this.args.metadata?.queries || this._loadedQueries || [];
    const query = queries.find((q) => q.id === id) || null;

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
              @session={{@session}}
            />
          {{/each}}
        </@form.Object>
      </@form.Section>
    {{/if}}
  </template>
}
