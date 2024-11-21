import DAG from "discourse/lib/dag";
import HeaderActivityCell from "./header/activity-cell";
import HeaderBulkSelectCell from "./header/bulk-select-cell";
import HeaderLikesCell from "./header/likes-cell";
import HeaderOpLikesCell from "./header/op-likes-cell";
import HeaderPostersCell from "./header/posters-cell";
import HeaderRepliesCell from "./header/replies-cell";
import HeaderTopicCell from "./header/topic-cell";
import HeaderViewsCell from "./header/views-cell";
import ItemActivityCell from "./item/activity-cell";
import ItemBulkSelectCell from "./item/bulk-select-cell";
import ItemLikesCell from "./item/likes-cell";
import ItemOpLikesCell from "./item/op-likes-cell";
import ItemPostersCell from "./item/posters-cell";
import ItemRepliesCell from "./item/replies-cell";
import ItemTopicCell from "./item/topic-cell";
import ItemViewsCell from "./item/views-cell";

export function createColumns() {
  const columns = new DAG();
  columns.add("bulk-select", {
    header: HeaderBulkSelectCell,
    item: ItemBulkSelectCell,
  });
  columns.add("topic", {
    header: HeaderTopicCell,
    item: ItemTopicCell,
  });
  columns.add("posters", {
    header: HeaderPostersCell,
    item: ItemPostersCell,
  });
  columns.add("replies", {
    header: HeaderRepliesCell,
    item: ItemRepliesCell,
  });
  columns.add("likes", {
    header: HeaderLikesCell,
    item: ItemLikesCell,
  });
  columns.add("op-likes", {
    header: HeaderOpLikesCell,
    item: ItemOpLikesCell,
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
