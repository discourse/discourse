import SiteTextThemeRow from "discourse/admin/components/site-text-theme-row";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class SiteTextThemeSelector extends ComboBox {
  modifyComponentForRow() {
    return SiteTextThemeRow;
  }

  modifySelection(item) {
    if (item?.id == null) {
      return item;
    }
    return { ...item, name: `${item.name} #${item.id}` };
  }
}
