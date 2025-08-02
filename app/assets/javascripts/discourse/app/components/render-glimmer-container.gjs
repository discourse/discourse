import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class RenderGlimmerContainer extends Component {
  @service renderGlimmer;

  <template>
    {{~#each this.renderGlimmer._registrations as |info|~}}
      {{~#in-element info.element insertBefore=null~}}
        <info.component
          @data={{info.data}}
          @setWrapperElementAttrs={{info.setWrapperElementAttrs}}
        />
      {{~/in-element~}}
    {{~/each~}}
  </template>
}
