import Badge from "discourse/models/badge";
import BadgeViewComponent from "../components/result-types/badge.gjs";
import CategoryViewComponent from "../components/result-types/category.gjs";
import GroupViewComponent from "../components/result-types/group.gjs";
import HtmlViewComponent from "../components/result-types/html.gjs";
import JsonViewComponent from "../components/result-types/json.gjs";
import PostViewComponent from "../components/result-types/post.gjs";
import ReltimeViewComponent from "../components/result-types/reltime.gjs";
import ReviewableViewComponent from "../components/result-types/reviewable.gjs";
import TagGroupViewComponent from "../components/result-types/tag-group.gjs";
import TextViewComponent from "../components/result-types/text.gjs";
import TopicViewComponent from "../components/result-types/topic.gjs";
import UrlViewComponent from "../components/result-types/url.gjs";
import UserViewComponent from "../components/result-types/user.gjs";

export const VIEW_COMPONENTS = {
  topic: TopicViewComponent,
  text: TextViewComponent,
  post: PostViewComponent,
  reltime: ReltimeViewComponent,
  reviewable: ReviewableViewComponent,
  badge: BadgeViewComponent,
  url: UrlViewComponent,
  user: UserViewComponent,
  group: GroupViewComponent,
  html: HtmlViewComponent,
  json: JsonViewComponent,
  category: CategoryViewComponent,
  tag_group: TagGroupViewComponent,
};

export function transformedRelTable(table, modelClass) {
  return Object.fromEntries(
    (table ?? []).map((item) => [
      item.id,
      modelClass ? modelClass.create(item) : item,
    ])
  );
}

export function relationLabel(relation) {
  return relation?.username ?? relation?.title ?? relation?.name;
}

export function buildRelationTables(relations, site) {
  const tables = {
    group: site.groupsById,
    category: transformedRelTable(site.categories),
  };

  for (const [type, table] of Object.entries(relations ?? {})) {
    if (tables[type]) {
      continue;
    }

    tables[type] = transformedRelTable(
      table,
      type === "badge" ? Badge : undefined
    );
  }

  return tables;
}

export function buildColumnComponents(
  content,
  relationTables,
  viewComponents = VIEW_COMPONENTS
) {
  const {
    columns,
    colrender = {},
    hidden_relations: hiddenRelations = {},
  } = content ?? {};

  if (!columns) {
    return [];
  }

  return columns.map((_, idx) => {
    const requested = colrender[idx];
    const type = requested && viewComponents[requested] ? requested : "text";

    return {
      name: type,
      component: viewComponents[type],
      table: relationTables[type],
      hidden: hiddenRelations[type],
    };
  });
}

export function displayColumnNames(columns) {
  return (columns ?? []).map((colName) => {
    if (colName.endsWith("_id")) {
      return colName.slice(0, -3);
    }
    const dIdx = colName.indexOf("$");
    if (dIdx >= 0) {
      return colName.substring(dIdx + 1);
    }
    return colName;
  });
}
