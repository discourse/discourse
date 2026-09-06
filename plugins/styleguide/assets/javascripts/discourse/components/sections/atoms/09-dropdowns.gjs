import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CategoriesAdminDropdownExample from "../../examples/atoms/dropdowns/categories-admin-dropdown";
import categoriesAdminDropdownSource from "../../examples/atoms/dropdowns/categories-admin-dropdown?source=file";
import CategoryChooserExample from "../../examples/atoms/dropdowns/category-chooser";
import categoryChooserSource from "../../examples/atoms/dropdowns/category-chooser?source=file";
import CategoryNotificationsTrackingExample from "../../examples/atoms/dropdowns/category-notifications-tracking";
import categoryNotificationsTrackingSource from "../../examples/atoms/dropdowns/category-notifications-tracking?source=file";
import ComboBoxExample from "../../examples/atoms/dropdowns/combo-box";
import comboBoxSource from "../../examples/atoms/dropdowns/combo-box?source=file";
import ComboBoxClearableExample from "../../examples/atoms/dropdowns/combo-box-clearable";
import comboBoxClearableSource from "../../examples/atoms/dropdowns/combo-box-clearable?source=file";
import ComboBoxFilterableExample from "../../examples/atoms/dropdowns/combo-box-filterable";
import comboBoxFilterableSource from "../../examples/atoms/dropdowns/combo-box-filterable?source=file";
import ComboBoxNoneExample from "../../examples/atoms/dropdowns/combo-box-none";
import comboBoxNoneSource from "../../examples/atoms/dropdowns/combo-box-none?source=file";
import DropdownSelectBoxExample from "../../examples/atoms/dropdowns/dropdown-select-box";
import dropdownSelectBoxSource from "../../examples/atoms/dropdowns/dropdown-select-box?source=file";
import FutureDateInputSelectorExample from "../../examples/atoms/dropdowns/future-date-input-selector";
import futureDateInputSelectorSource from "../../examples/atoms/dropdowns/future-date-input-selector?source=file";
import GroupChooserExample from "../../examples/atoms/dropdowns/group-chooser";
import groupChooserSource from "../../examples/atoms/dropdowns/group-chooser?source=file";
import IconGridPickerExample from "../../examples/atoms/dropdowns/icon-grid-picker";
import iconGridPickerSource from "../../examples/atoms/dropdowns/icon-grid-picker?source=file";
import ListSettingExample from "../../examples/atoms/dropdowns/list-setting";
import listSettingSource from "../../examples/atoms/dropdowns/list-setting?source=file";
import ListSettingNamePropertyExample from "../../examples/atoms/dropdowns/list-setting-name-property";
import listSettingNamePropertySource from "../../examples/atoms/dropdowns/list-setting-name-property?source=file";
import MiniTagChooserExample from "../../examples/atoms/dropdowns/mini-tag-chooser";
import miniTagChooserSource from "../../examples/atoms/dropdowns/mini-tag-chooser?source=file";
import MiniTagChooserHeaderFilterExample from "../../examples/atoms/dropdowns/mini-tag-chooser-header-filter";
import miniTagChooserHeaderFilterSource from "../../examples/atoms/dropdowns/mini-tag-chooser-header-filter?source=file";
import MultiSelectExample from "../../examples/atoms/dropdowns/multi-select";
import multiSelectSource from "../../examples/atoms/dropdowns/multi-select?source=file";
import PinnedButtonExample from "../../examples/atoms/dropdowns/pinned-button";
import pinnedButtonSource from "../../examples/atoms/dropdowns/pinned-button?source=file";
import PinnedOptionsExample from "../../examples/atoms/dropdowns/pinned-options";
import pinnedOptionsSource from "../../examples/atoms/dropdowns/pinned-options?source=file";
import TopicNotificationsTrackingExample from "../../examples/atoms/dropdowns/topic-notifications-tracking";
import topicNotificationsTrackingSource from "../../examples/atoms/dropdowns/topic-notifications-tracking?source=file";
import UserNotificationsDropdownExample from "../../examples/atoms/dropdowns/user-notifications-dropdown";
import userNotificationsDropdownSource from "../../examples/atoms/dropdowns/user-notifications-dropdown?source=file";

export default <template>
  <StyleguideExample @title="<ComboBox>" @code={{comboBoxSource}}>
    <ComboBoxExample />
  </StyleguideExample>

  <StyleguideExample
    @title="filterable <ComboBox>"
    @code={{comboBoxFilterableSource}}
  >
    <ComboBoxFilterableExample @categories={{@dummy.categories}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<ComboBox> with a default state"
    @code={{comboBoxNoneSource}}
  >
    <ComboBoxNoneExample />
  </StyleguideExample>

  <StyleguideExample
    @title="<ComboBox> clearable"
    @code={{comboBoxClearableSource}}
  >
    <ComboBoxClearableExample />
  </StyleguideExample>

  <StyleguideExample
    @title="<TopicNotificationsTracking>"
    @code={{topicNotificationsTrackingSource}}
  >
    <TopicNotificationsTrackingExample />
  </StyleguideExample>

  <StyleguideExample @title="<CategoryChooser>" @code={{categoryChooserSource}}>
    <CategoryChooserExample />
  </StyleguideExample>

  <StyleguideExample @title="<PinnedButton>" @code={{pinnedButtonSource}}>
    <PinnedButtonExample @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample @title="<PinnedOptions>" @code={{pinnedOptionsSource}}>
    <PinnedOptionsExample @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<CategoriesAdminDropdown>"
    @code={{categoriesAdminDropdownSource}}
  >
    <CategoriesAdminDropdownExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<CategoryNotificationsTracking>"
    @code={{categoryNotificationsTrackingSource}}
  >
    <CategoryNotificationsTrackingExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<DropdownSelectBox>"
    @code={{dropdownSelectBoxSource}}
  >
    <DropdownSelectBoxExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<FutureDateInputSelector>"
    @code={{futureDateInputSelectorSource}}
  >
    <FutureDateInputSelectorExample />
  </StyleguideExample>

  <StyleguideExample @title="<MultiSelect>" @code={{multiSelectSource}}>
    <MultiSelectExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample @title="<MiniTagChooser>" @code={{miniTagChooserSource}}>
    <div class="inline-form">
      <MiniTagChooserExample />
    </div>
  </StyleguideExample>

  <StyleguideExample
    @title="<MiniTagChooser> with useHeaderFilter=true"
    @code={{miniTagChooserHeaderFilterSource}}
  >
    <div class="inline-form">
      <MiniTagChooserHeaderFilterExample />
    </div>
  </StyleguideExample>

  <StyleguideExample @title="admin <GroupChooser>" @code={{groupChooserSource}}>
    <GroupChooserExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample @title="<ListSetting>" @code={{listSettingSource}}>
    <ListSettingExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<ListSetting> with a name property"
    @code={{listSettingNamePropertySource}}
  >
    <ListSettingNamePropertyExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<UserNotificationsDropdown>"
    @code={{userNotificationsDropdownSource}}
  >
    <UserNotificationsDropdownExample />
  </StyleguideExample>

  <StyleguideExample @title="<DIconGridPicker>" @code={{iconGridPickerSource}}>
    <IconGridPickerExample />
  </StyleguideExample>
</template>
