import { on } from "@ember/modifier";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import ParamInputForm from "../../../components/param-input-form";
import QueryResult from "../../../components/query-result";
import QueryResultDownloadButtons from "../../../components/query-result-download-buttons";

export default <template>
  <section class="user-content">
    <h1>{{@controller.model.name}}</h1>
    <p>{{@controller.model.description}}</p>

    <form class="query-run" {{on "submit" @controller.run}}>
      {{#if @controller.hasParams}}
        <ParamInputForm
          @initialValues={{@controller.parsedParams}}
          @onRegisterApi={{@controller.onRegisterApi}}
          @paramInfo={{@controller.model.param_info}}
        />
      {{/if}}

      <div class="query-run-actions">
        <div class="query-run-actions__left">
          <DButton
            class="btn-primary query-run__submit"
            @action={{@controller.run}}
            @icon="play"
            @label="explorer.run"
            @type="submit"
            {{didInsert @controller.runOnLoad}}
          />

          <DButton
            class="btn-default query-group-bookmark
              {{if @controller.queryGroupBookmark 'bookmarked'}}"
            @action={{@controller.toggleBookmark}}
            @icon={{@controller.bookmarkIcon}}
            @translatedLabel={{@controller.bookmarkLabel}}
          />
        </div>

        {{#if @controller.showResults}}
          <div class="query-run-actions__right">
            <QueryResultDownloadButtons
              class="query-result-download-buttons--inline"
              @content={{@controller.results}}
              @group={{@controller.group}}
              @query={{@controller.model}}
            />
          </div>
        {{/if}}
      </div>
    </form>

    <hr />

    <DConditionalLoadingSpinner @condition={{@controller.loading}} />

    {{#if @controller.results}}
      <div class="query-results">
        {{#if @controller.showResults}}
          <QueryResult
            @content={{@controller.results}}
            @group={{@controller.group}}
            @query={{@controller.model}}
            @showDownloads={{false}}
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
