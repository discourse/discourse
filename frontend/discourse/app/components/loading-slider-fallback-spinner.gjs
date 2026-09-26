import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import LoadingSliderService from "discourse/services/loading-slider";

export default class LoadingSliderFallbackSpinner extends Component {
  @service(() => LoadingSliderService) loadingSlider;

  get shouldDisplay() {
    const { mode, loading, stillLoading } = this.loadingSlider;
    return (
      (mode === "spinner" && loading) || (mode === "slider" && stillLoading)
    );
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="route-loading-spinner">{{dLoadingSpinner}}</div>
      {{bodyClass "has-route-loading-spinner"}}
      {{hideApplicationFooter}}
    {{/if}}
  </template>
}
