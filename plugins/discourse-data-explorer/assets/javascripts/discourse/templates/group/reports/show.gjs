import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import ParamInputForm from "../../../components/param-input-form";
import QueryResult from "../../../components/query-result";

export default <template>
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
        {{didInsert @controller.runOnLoad}}
        @action={{@controller.run}}
        @icon="play"
        @label="explorer.run"
        @type="submit"
        class="btn-primary query-run__submit"
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
