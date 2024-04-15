import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class LoadingSliderFallbackSpinner extends Component {
  @service loadingSlider;

  get shouldDisplay() {
    const { mode, loading, stillLoading } = this.loadingSlider;
    return (
      (mode === "spinner" && loading) || (mode === "slider" && stillLoading)
    );
  }
}
