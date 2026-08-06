import { hash } from "@ember/helper";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

const TAGS = ["apple", "orange", "potato"];

export default <template>
  <MiniTagChooser @value={{TAGS}} @options={{hash filterable=true}} />
</template>
