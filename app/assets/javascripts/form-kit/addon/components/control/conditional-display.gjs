import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import uniqueId from "discourse/helpers/unique-id";
import FkControlConditionalDisplayCondition from "./conditional-display/condition";
import FkControlConditionalDisplayContent from "./conditional-display/content";

const Conditions = <template>
  {{yield
    (component
      FkControlConditionalDisplayCondition
      id=@id
      name=@name
      setCondition=@setCondition
      active=(eq @activeName @name)
    )
  }}
</template>;

const Contents = <template>
  {{yield
    (component FkControlConditionalDisplayContent activeName=@activeName)
  }}
</template>;

export default class FkControlConditionalDisplay extends Component {
  @tracked activeName = this.args.activeName;

  id = uniqueId();

  @action
  setCondition(name) {
    this.activeName = name;
  }

  <template>
    <div class="d-form-conditional-display">
      {{yield
        (hash
          Conditions=(component
            Conditions
            activeName=this.activeName
            setCondition=this.setCondition
            id=this.id
          )
          Contents=(component Contents activeName=this.activeName)
        )
      }}
    </div>
  </template>
}
