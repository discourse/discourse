import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FKControlConditionalDisplayCondition from "./conditional-content/condition";
import FKControlConditionalContentContent from "./conditional-content/content";

const Conditions = <template>
  <div class="form-kit__inline-radio">
    {{yield
      (component
        FKControlConditionalDisplayCondition
        activeName=@activeName
        setCondition=@setCondition
        resyncToken=@resyncToken
      )
    }}
  </div>
</template>;

const Contents = <template>
  {{yield
    (component FKControlConditionalContentContent activeName=@activeName)
  }}
</template>;

export default class FKControlConditionalContent extends Component {
  @tracked manuallySetName = null;
  // Bumped after `onChange` settles so the radio inputs re-assert their checked
  // state to match `activeName`, even when the value did not change (e.g. the
  // parent rejected the change). Without this, a native radio click that gets
  // vetoed stays visually selected.
  @tracked resyncToken = 0;

  get activeName() {
    // If onChange is provided, parent controls state - always use @activeName
    if (this.args.onChange) {
      return this.args.activeName;
    }
    return this.manuallySetName ?? this.args.activeName;
  }

  @action
  setCondition(name) {
    this.manuallySetName = name;

    if (this.args.onChange) {
      Promise.resolve(this.args.onChange(name)).finally(() => {
        this.resyncToken++;
      });
    }
  }

  <template>
    <div class="form-kit__conditional-display">
      {{yield
        (hash
          Conditions=(component
            Conditions
            activeName=this.activeName
            setCondition=this.setCondition
            resyncToken=this.resyncToken
          )
          Contents=(component Contents activeName=this.activeName)
        )
      }}
    </div>
  </template>
}
