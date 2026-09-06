import { classNames } from "@ember-decorators/component";
import ComboBox from "discourse/select-kit/components/combo-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";

@classNames("ai-log-feature-filter")
@selectKitOptions({
  allowAny: false,
  clearable: true,
  filterable: true,
})
export default class AiLogFeatureFilter extends ComboBox {
  search(filter) {
    const matches = super.search(filter);

    if (!filter || matches.includes(filter)) {
      return matches;
    }

    return [filter, ...matches];
  }
}
