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
      @body={{@controller.model.emptyState.body}}
      @title={{@controller.model.emptyState.title}}
    />
  {{else}}
    <DLoadMore class="paginated-topics-list" @action={{@controller.loadMore}}>
      <TopicDismissButtons
        @dismissRead={{if
          @controller.showDismissRead
          (routeAction "dismissReadTopics")
        }}
        @model={{@controller.model}}
        @position="top"
        @resetNew={{@controller.resetNew}}
        @selectedTopics={{@controller.bulkSelectHelper.selected}}
        @showDismissRead={{@controller.showDismissRead}}
        @showResetNew={{@controller.showResetNew}}
      />

      {{#if (or @controller.model.loadingBefore @controller.incomingCount)}}
        <div class="show-mores">
          <a
            class="alert alert-info clickable
              {{if @controller.model.loadingBefore 'loading'}}"
            href
            tabindex="0"
            {{on "click" @controller.showInserted}}
          >
            <DCountI18n
              @count={{or
                @controller.model.loadingBefore
                @controller.incomingCount
              }}
              @key="topic_count_latest"
            />
            {{#if @model.loadingBefore}}
              {{dLoadingSpinner size="small"}}
            {{/if}}
          </a>
        </div>
      {{/if}}

      <BasicTopicList
        @ascending={{@controller.ascending}}
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @changeSort={{@controller.changeSort}}
        @focusLastVisitedTopic={{true}}
        @hideCategory={{@controller.hideCategory}}
        @listContext={{@controller.listContext}}
        @order={{@controller.order}}
        @showPosters={{@controller.showPosters}}
        @tagsForUser={{@controller.tagsForUser}}
        @topicList={{@controller.model}}
      />

      {{#if @controller.showBottomDismissButtons}}
        <TopicDismissButtons
          @dismissRead={{if
            @controller.showDismissRead
            (routeAction "dismissReadTopics")
          }}
          @model={{@controller.model}}
          @position="bottom"
          @resetNew={{@controller.resetNew}}
          @selectedTopics={{@controller.bulkSelectHelper.selected}}
          @showDismissRead={{@controller.showDismissRead}}
          @showResetNew={{@controller.showResetNew}}
        />
      {{/if}}
      <DConditionalLoadingSpinner
        @condition={{@controller.model.loadingMore}}
      />
    </DLoadMore>
  {{/if}}
</template>
