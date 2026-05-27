import Component from "@glimmer/component";
import HeaderActivityCell from "discourse/components/topic-list/header/activity-cell";
import HeaderLikesCell from "discourse/components/topic-list/header/likes-cell";
import HeaderPostersCell from "discourse/components/topic-list/header/posters-cell";
import HeaderRepliesCell from "discourse/components/topic-list/header/replies-cell";
import HeaderTopicCell from "discourse/components/topic-list/header/topic-cell";
import HeaderViewsCell from "discourse/components/topic-list/header/views-cell";
import Item from "discourse/components/topic-list/item";
import ItemActivityCell from "discourse/components/topic-list/item/activity-cell";
import ItemLikesCell from "discourse/components/topic-list/item/likes-cell";
import ItemPostersCell from "discourse/components/topic-list/item/posters-cell";
import ItemRepliesCell from "discourse/components/topic-list/item/replies-cell";
import ItemTopicCell from "discourse/components/topic-list/item/topic-cell";
import ItemViewsCell from "discourse/components/topic-list/item/views-cell";
import DAG from "discourse/lib/dag";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicList extends Component {
  itemCode = `import Item from "discourse/components/topic-list/item";

// The columns definition is usually provided by the parent component
// See TopicList for an example
<template>
  <Item @topic={{@dummy.topic}} @columns={{this.columns}} />
</template>`;

  get columns() {
    const defaultColumns = new DAG({
      // Allow customizations to replace just a header cell or just an item cell
      onReplaceItem(_, newValue, oldValue) {
        newValue.header ??= oldValue.header;
        newValue.item ??= oldValue.item;
      },
    });

    defaultColumns.add("topic", {
      header: HeaderTopicCell,
      item: ItemTopicCell,
    });

    if (this.args.showPosters) {
      defaultColumns.add("posters", {
        header: HeaderPostersCell,
        item: ItemPostersCell,
      });
    }

    defaultColumns.add("replies", {
      header: HeaderRepliesCell,
      item: ItemRepliesCell,
    });

    defaultColumns.add("likes", {
      header: HeaderLikesCell,
      item: ItemLikesCell,
    });

    defaultColumns.add("views", {
      header: HeaderViewsCell,
      item: ItemViewsCell,
    });

    defaultColumns.add("activity", {
      header: HeaderActivityCell,
      item: ItemActivityCell,
    });

    return applyMutableValueTransformer(
      "topic-list-columns",
      defaultColumns,
      {}
    ).resolve();
  }

  <template>
    <StyleguideExample @title="<TopicListItem>" @code={{this.itemCode}}>
      <table class="topic-list">
        <tbody>
          <Item @topic={{@dummy.topic}} @columns={{this.columns}} />
        </tbody>
      </table>
    </StyleguideExample>
  </template>
}
