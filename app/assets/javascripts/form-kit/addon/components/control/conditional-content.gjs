import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import uniqueId from "discourse/helpers/unique-id";
import FKControlConditionalDisplayCondition from "./conditional-content/condition";
import FKControlConditionalContentContent from "./conditional-content/content";

const Conditions = <template>
  {{yield
    (component
      FKControlConditionalDisplayCondition
      activeName=@activeName
      id=@id
      setCondition=@setCondition
    )
  }}
</template>;

const Contents = <template>
  {{yield
    (component FKControlConditionalContentContent activeName=@activeName)
  }}
</template>;

export default class FkControlConditionalContent extends Component {
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
          Contents=(component Contents activeName=this.activeName id=this.id)
        )
      }}
    </div>
  </template>
}
