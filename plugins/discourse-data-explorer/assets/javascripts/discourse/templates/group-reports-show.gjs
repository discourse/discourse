import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import ParamInputForm from "../components/param-input-form";
import QueryResult from "../components/query-result";

export default RouteTemplate(
  <template>
    <section class="user-content">
      <h1>{{@controller.model.name}}</h1>
      <p>{{@controller.model.description}}</p>

      <form class="query-run" {{on "submit" @controller.run}}>
        {{#if @controller.hasParams}}
          <ParamInputForm
            @initialValues={{@controller.parsedParams}}
            @paramInfo={{@controller.model.param_info}}
            @onRegisterApi={{@controller.onRegisterApi}}
          />
        {{/if}}

        <DButton
          @action={{@controller.run}}
          @icon="play"
          @label="explorer.run"
          @type="submit"
          class="btn-primary"
        />

        <DButton
          @action={{@controller.toggleBookmark}}
          @label={{@controller.bookmarkLabel}}
          @icon={{@controller.bookmarkIcon}}
          class={{@controller.bookmarkClassName}}
        />
      </form>

      <ConditionalLoadingSpinner @condition={{@controller.loading}} />

      {{#if @controller.results}}
        <div class="query-results">
          {{#if @controller.showResults}}
            <QueryResult
              @query={{@controller.model}}
              @content={{@controller.results}}
              @group={{@controller.group}}
            />
          {{else}}
            {{#each @controller.results.errors as |err|}}
              <pre class="query-error"><code>{{~err}}</code></pre>
            {{/each}}
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
);
