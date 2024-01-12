import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import i18n from "discourse-common/helpers/i18n";
import htmlSafe from "discourse-common/helpers/html-safe";

export default class BulkTopicActions extends Component {
  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="topic-bulk-actions-modal -large"
    >
      <:body>
        <div>
          {{htmlSafe (i18n "topics.bulk.selected" count=@model.topics.length)}}
        </div>
        <div>body</div>
      </:body>

      <:footer>
        {{#if @model.silent}}
          <div><input class="" id="silent" type="checkbox" />
            <label for="silent">Perform this action silently.</label>
          </div>
        {{/if}}
        <DButton
          @action={{@model.action}}
          @icon="check"
          @label="topics.bulk.confirm"
          id="bulk-topics-confirm"
          class="btn-primary"
        />
      </:footer>

    </DModal>
  </template>
}
