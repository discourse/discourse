import DAG from "discourse/lib/dag";
import HeaderActivityCell from "./header/activity-cell";
import HeaderBulkSelectCell from "./header/bulk-select";
import HeaderLikesCell from "./header/likes-cell";
import HeaderOpLikesCell from "./header/op-likes-cell";
import HeaderPostersCell from "./header/posters-cell";
import HeaderRepliesCell from "./header/replies-cell";
import HeaderTopicCell from "./header/topic-cell";
import HeaderViewsCell from "./header/views-cell";

export function createColumns() {
  const columns = new DAG();
  columns.add("topic-list-before-columns");
  columns.add("bulk-select", {
    header: HeaderBulkSelectCell,
    item: null,
  });
  columns.add("topic", {
    header: HeaderTopicCell,
    item: null,
  });
  columns.add("topic-list-after-main-link");
  columns.add("posters", {
    header: HeaderPostersCell,
    item: null,
  });
  columns.add("replies", {
    header: HeaderRepliesCell,
    item: null,
  });
  columns.add("likes", {
    header: HeaderLikesCell,
    item: null,
  });
  columns.add("op-likes", {
    header: HeaderOpLikesCell,
    item: null,
  });
  columns.add("views", {
    header: HeaderViewsCell,
    item: null,
  });
  columns.add("activity", {
    header: HeaderActivityCell,
    item: null,
  });
  columns.add("topic-list-after-columns");
  return columns;
}
