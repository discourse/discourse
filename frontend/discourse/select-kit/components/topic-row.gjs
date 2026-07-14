import { classNames } from "@ember-decorators/component";
import TopicStatus from "discourse/components/topic-status";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dBoundCategoryLink from "discourse/ui-kit/helpers/d-bound-category-link";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

@classNames("topic-row")
export default class TopicRow extends SelectKitRowComponent {
  <template>
    <TopicStatus @topic={{this.item}} @disableActions={{true}} />
    <div class="topic-title">{{dReplaceEmoji this.item.title}}</div>
    <div class="topic-categories">
      {{dBoundCategoryLink
        this.item.category
        ancestors=this.item.category.predecessors
        hideParent=true
        link=false
      }}
    </div>
  </template>
}
