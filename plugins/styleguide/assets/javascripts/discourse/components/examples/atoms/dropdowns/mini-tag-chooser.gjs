import { hash } from "@ember/helper";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

const TAGS = ["apple", "orange", "potato"];

export default <template>
  <MiniTagChooser @options={{hash filterable=true}} @value={{TAGS}} />
</template>
