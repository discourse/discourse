import { array } from "@ember/helper";
import SharedArtifactsList from "../../components/shared-artifacts-list.gjs";

export default <template>
  {{#each (array @model) key="@identity" as |data|}}
    <SharedArtifactsList @data={{data}} />
  {{/each}}
</template>
