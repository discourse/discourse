import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("topic-row")
export default class TopicRow extends SelectKitRowComponent {}

<TopicStatus @topic={{this.item}} @disableActions={{true}} />
<div class="topic-title">{{replace-emoji this.item.title}}</div>
<div class="topic-categories">
  {{bound-category-link
    this.item.category
    ancestors=this.item.category.predecessors
    hideParent=true
    link=false
  }}
</div>