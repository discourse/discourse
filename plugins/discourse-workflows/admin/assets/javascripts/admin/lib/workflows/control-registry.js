import BooleanControl from "../../components/workflows/configurators/boolean-control";
import CategoryControl from "../../components/workflows/configurators/category-control";
import CodeControl from "../../components/workflows/configurators/code-control";
import ComboBox from "../../components/workflows/configurators/combo-box";
import ConditionBuilder from "../../components/workflows/configurators/condition-builder";
import Credential from "../../components/workflows/configurators/credential";
import DataTableColumnSelect from "../../components/workflows/configurators/data-table-column-select";
import DataTableColumns from "../../components/workflows/configurators/data-table-columns";
import DataTableConditionBuilder from "../../components/workflows/configurators/data-table-condition-builder";
import DefaultInputControl from "../../components/workflows/configurators/default-input-control";
import FilterQuery from "../../components/workflows/configurators/filter-query";
import IconControl from "../../components/workflows/configurators/icon-control";
import MultiComboBox from "../../components/workflows/configurators/multi-combo-box";
import NoticeControl from "../../components/workflows/configurators/notice-control";
import QueryParams from "../../components/workflows/configurators/query-params";
import SelectControl from "../../components/workflows/configurators/select-control";
import TagsControl from "../../components/workflows/configurators/tags-control";
import UrlPreview from "../../components/workflows/configurators/url-preview";
import UserControl from "../../components/workflows/configurators/user-control";
import UserOrGroupControl from "../../components/workflows/configurators/user-or-group-control";

const CONTROL_REGISTRY = {
  notice: { kind: "standalone", renderer: NoticeControl },
  boolean: { kind: "standalone", renderer: BooleanControl },
  condition_builder: { kind: "standalone", renderer: ConditionBuilder },
  data_table_condition_builder: {
    kind: "standalone",
    renderer: DataTableConditionBuilder,
  },
  data_table_columns: { kind: "standalone", renderer: DataTableColumns },
  query_params: { kind: "standalone", renderer: QueryParams },

  code: { kind: "field", type: "code", renderer: CodeControl },
  combo_box: { kind: "field", type: "custom", renderer: ComboBox },
  credential: { kind: "field", type: "custom", renderer: Credential },
  data_table_column_select: {
    kind: "field",
    type: "custom",
    renderer: DataTableColumnSelect,
  },
  multi_combo_box: { kind: "field", type: "custom", renderer: MultiComboBox },
  filter_query: { kind: "field", type: "custom", renderer: FilterQuery },
  url_preview: { kind: "field", type: "custom", renderer: UrlPreview },
  tags: { kind: "field", type: "custom", renderer: TagsControl },
  category: { kind: "field", type: "custom", renderer: CategoryControl },
  user: { kind: "field", type: "custom", renderer: UserControl },
  user_or_group: {
    kind: "field",
    type: "custom",
    renderer: UserOrGroupControl,
  },
  select: { kind: "field", type: "select", renderer: SelectControl },
  icon: { kind: "field", type: "icon", renderer: IconControl },

  default: {
    kind: "field",
    type: ({ inputType }) => `input-${inputType}`,
    renderer: DefaultInputControl,
  },
};

export default CONTROL_REGISTRY;
