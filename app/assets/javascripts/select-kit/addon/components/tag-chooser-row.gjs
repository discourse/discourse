import { classNames } from "@ember-decorators/component";
import discourseTag from "discourse/helpers/discourse-tag";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("tag-chooser-row")
export default class TagChooserRow extends SelectKitRowComponent {
  <template>
    {{discourseTag this.rowValue count=this.item.count noHref=true}}
  </template>
}
