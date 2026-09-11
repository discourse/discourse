import ActorControl from "../../components/workflows/configurators/actor-control.gjs";
import BooleanControl from "../../components/workflows/configurators/boolean-control.gjs";
import CategoryControl from "../../components/workflows/configurators/category-control.gjs";
import CodeControl from "../../components/workflows/configurators/code-control.gjs";
import ComboBox from "../../components/workflows/configurators/combo-box.gjs";
import ConditionBuilder from "../../components/workflows/configurators/condition-builder.gjs";
import Credential from "../../components/workflows/configurators/credential.gjs";
import DataTableColumnSelect from "../../components/workflows/configurators/data-table-column-select.gjs";
import DataTableColumns from "../../components/workflows/configurators/data-table-columns.gjs";
import DataTableConditionBuilder from "../../components/workflows/configurators/data-table-condition-builder.gjs";
import DataTableSelect from "../../components/workflows/configurators/data-table-select.gjs";
import DefaultInputControl from "../../components/workflows/configurators/default-input-control.gjs";
import FieldPathControl from "../../components/workflows/configurators/field-path-control.gjs";
import FilterQuery from "../../components/workflows/configurators/filter-query.gjs";
import GroupSelect from "../../components/workflows/configurators/group-select.gjs";
import IconControl from "../../components/workflows/configurators/icon-control.gjs";
import MultiComboBox from "../../components/workflows/configurators/multi-combo-box.gjs";
import MultiInput from "../../components/workflows/configurators/multi-input.gjs";
import NoticeControl from "../../components/workflows/configurators/notice-control.gjs";
import QueryParams from "../../components/workflows/configurators/query-params.gjs";
import SelectControl from "../../components/workflows/configurators/select-control.gjs";
import SummarizeAggregations from "../../components/workflows/configurators/summarize-aggregations.gjs";
import TagsControl from "../../components/workflows/configurators/tags-control.gjs";
import TimezoneControl from "../../components/workflows/configurators/timezone-control.gjs";
import UrlPreview from "../../components/workflows/configurators/url-preview.gjs";
import UserControl from "../../components/workflows/configurators/user-control.gjs";
import UserOrGroupControl from "../../components/workflows/configurators/user-or-group-control.gjs";
import UserSeenTriggerOptions from "../../components/workflows/configurators/user-seen-trigger-options.gjs";

const FIELD_CONTROL_REGISTRY = {
  notice: { kind: "standalone", renderer: NoticeControl },
  actor: { kind: "field", type: "custom", renderer: ActorControl },
  boolean: { kind: "standalone", renderer: BooleanControl },
  condition_builder: { kind: "standalone", renderer: ConditionBuilder },
  data_table_condition_builder: {
    kind: "standalone",
    renderer: DataTableConditionBuilder,
  },
  data_table_columns: { kind: "standalone", renderer: DataTableColumns },
  query_params: { kind: "standalone", renderer: QueryParams },
  summarize_aggregations: {
    kind: "standalone",
    renderer: SummarizeAggregations,
  },
  user_seen_trigger_options: {
    kind: "standalone",
    renderer: UserSeenTriggerOptions,
  },

  code: { kind: "field", type: "code", renderer: CodeControl },
  combo_box: { kind: "field", type: "custom", renderer: ComboBox },
  credential: { kind: "field", type: "custom", renderer: Credential },
  data_table_select: {
    kind: "field",
    type: "custom",
    renderer: DataTableSelect,
  },
  group_select: { kind: "field", type: "custom", renderer: GroupSelect },
  data_table_column_select: {
    kind: "field",
    type: "custom",
    renderer: DataTableColumnSelect,
  },
  multi_combo_box: { kind: "field", type: "custom", renderer: MultiComboBox },
  multi_input: { kind: "field", type: "custom", renderer: MultiInput },
  filter_query: { kind: "field", type: "custom", renderer: FilterQuery },
  field_path: { kind: "field", type: "custom", renderer: FieldPathControl },
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
  checkbox: { kind: "field", type: "checkbox", renderer: DefaultInputControl },
  textarea: { kind: "field", type: "textarea", renderer: DefaultInputControl },
  time: { kind: "field", type: "input-time", renderer: DefaultInputControl },
  date_time: {
    kind: "field",
    type: "input-datetime-local",
    renderer: DefaultInputControl,
  },
  timezone: { kind: "field", type: "custom", renderer: TimezoneControl },

  default: {
    kind: "field",
    type: ({ inputType }) => `input-${inputType}`,
    renderer: DefaultInputControl,
  },
};

export default FIELD_CONTROL_REGISTRY;
