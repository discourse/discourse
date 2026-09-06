import { hash } from "@ember/helper";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";

const OPTIONS = [
  { id: 1, name: "Orange" },
  { id: 2, name: "Blue" },
  { id: 3, name: "Red" },
  { id: 4, name: "Yellow" },
];

export default <template>
  <DropdownSelectBox
    @content={{OPTIONS}}
    @onChange={{@onChange}}
    @options={{hash translatedNone="Something"}}
  />
</template>
