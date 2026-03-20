import { on } from "@ember/modifier";
import BasicTopicList from "discourse/components/basic-topic-list";
import TopicDismissButtons from "discourse/components/topic-dismiss-buttons";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import routeAction from "discourse/helpers/route-action";
import { or } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DCountI18n from "discourse/ui-kit/d-count-i18n";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default <template>
  {{#if @controller.model.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}

  {{#if @controller.noContent}}
    <DEmptyState
      @title={{@controller.model.emptyState.title}}
      @body={{@controller.model.emptyState.body}}
    />
  {{else}}
    <DLoadMore @action={{@controller.loadMore}} class="paginated-topics-list">
      <TopicDismissButtons
        @position="top"
        @selectedTopics={{@controller.bulkSelectHelper.selected}}
        @model={{@controller.model}}
        @showResetNew={{@controller.showResetNew}}
        @showDismissRead={{@controller.showDismissRead}}
        @resetNew={{@controller.resetNew}}
        @dismissRead={{if
          @controller.showDismissRead
          (routeAction "dismissReadTopics")
        }}
      />

      {{#if (or @controller.model.loadingBefore @controller.incomingCount)}}
        <div class="show-mores">
          <a
            tabindex="0"
            href
            {{on "click" @controller.showInserted}}
            class="alert alert-info clickable
              {{if @controller.model.loadingBefore 'loading'}}"
          >
            <DCountI18n
              @key="topic_count_latest"
              @count={{or
                @controller.model.loadingBefore
                @controller.incomingCount
              }}
            />
            {{#if @model.loadingBefore}}
              {{dLoadingSpinner size="small"}}
            {{/if}}
          </a>
        </div>
      {{/if}}

      <BasicTopicList
        @topicList={{@controller.model}}
        @hideCategory={{@controller.hideCategory}}
        @showPosters={{@controller.showPosters}}
        @tagsForUser={{@controller.tagsForUser}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @changeSort={{@controller.changeSort}}
        @order={{@controller.order}}
        @ascending={{@controller.ascending}}
        @focusLastVisitedTopic={{true}}
        @listContext={{@controller.listContext}}
      />

      <TopicDismissButtons
        @position="bottom"
        @selectedTopics={{@controller.bulkSelectHelper.selected}}
        @model={{@controller.model}}
        @showResetNew={{@controller.showResetNew}}
        @showDismissRead={{@controller.showDismissRead}}
        @resetNew={{@controller.resetNew}}
        @dismissRead={{if
          @controller.showDismissRead
          (routeAction "dismissReadTopics")
        }}
      />

      <DConditionalLoadingSpinner
        @condition={{@controller.model.loadingMore}}
      />
    </DLoadMore>
  {{/if}}
</template>
