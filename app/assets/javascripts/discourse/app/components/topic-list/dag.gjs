import DAG from "discourse/lib/dag";
import HeaderActivityCell from "./header/activity-cell";
import HeaderRepliesCell from "./header/replies-cell";
import HeaderTopicCell from "./header/topic-cell";
import HeaderViewsCell from "./header/views-cell";
import ItemActivityCell from "./item/activity-cell";
import ItemRepliesCell from "./item/replies-cell";
import ItemTopicCell from "./item/topic-cell";
import ItemViewsCell from "./item/views-cell";

export function createColumns() {
  const columns = new DAG({
    // Allow customizations to replace just a header cell or just an item cell
    onReplaceItem(_, newValue, oldValue) {
      newValue.header ??= oldValue.header;
      newValue.item ??= oldValue.item;
    },
  });
  columns.add("topic", {
    header: HeaderTopicCell,
    item: ItemTopicCell,
  });
  columns.add("replies", {
    header: HeaderRepliesCell,
    item: ItemRepliesCell,
  });
  columns.add("views", {
    header: HeaderViewsCell,
    item: ItemViewsCell,
  });
  columns.add("activity", {
    header: HeaderActivityCell,
    item: ItemActivityCell,
  });
  return columns;
}
