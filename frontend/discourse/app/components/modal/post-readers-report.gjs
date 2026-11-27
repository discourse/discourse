import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class PostReadersReport extends Component {
  @tracked report;
  @tracked error;
  @tracked loading = true;

  @action
  async loadReport() {
    try {
      this.report = await ajax(
        `/post_readers/${this.args.model.postId}/staff_report.json`
      );
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      class="post-readers-report"
      @closeModal={{@closeModal}}
      @flash={{this.error}}
      @flashType="error"
      @title={{i18n "post.readers_report.title"}}
      {{didInsert this.loadReport}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.report}}
            {{#if this.report.readers.length}}
              {{#if this.report.truncated}}
                <p>{{i18n
                    "post.readers_report.truncated"
                    count=this.report.limit
                  }}</p>
              {{/if}}
              <table class="d-table">
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th class="d-table__cell" scope="col">{{i18n
                        "post.readers_report.reader"
                      }}</th>
                    <th class="d-table__cell" scope="col">{{i18n
                        "post.readers_report.last_topic_visit"
                      }}</th>
                  </tr>
                </thead>
                <tbody class="d-table__body">
                  {{#each this.report.readers as |reader|}}
                    <tr class="d-table__row">
                      <td class="d-table__cell">
                        <DUserAvatar @size="small" @user={{reader}} />
                        <DUserLink
                          @user={{reader}}
                        >{{reader.username}}</DUserLink>
                      </td>
                      <td class="d-table__cell">
                        {{#if reader.last_visited_at}}
                          {{dFormatDate reader.last_visited_at}}
                        {{else}}
                          {{i18n "post.readers_report.no_topic_visit"}}
                        {{/if}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <p>{{i18n "post.readers_report.empty"}}</p>
            {{/if}}
          {{/if}}
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
