import Component from "@glimmer/component";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";

export default class AddSynonymsConfirmation extends Component {
  get synonymNames() {
    return this.args.model.synonymNames;
  }

  get tagName() {
    return this.args.model.tagName;
  }

  <template>
    <p>
      <DInterpolatedTranslation
        @key="tagging.settings.add_synonyms_confirm"
        as |Placeholder|
      >
        <Placeholder @name="synonymNames">
          <b>{{this.synonymNames}}</b>
        </Placeholder>
        <Placeholder @name="tagName">
          <b>{{this.tagName}}</b>
        </Placeholder>
      </DInterpolatedTranslation>
    </p>
  </template>
}
