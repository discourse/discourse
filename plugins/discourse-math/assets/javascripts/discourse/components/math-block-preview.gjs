import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "discourse/plugins/discourse-math/lib/math-renderer";

export default class MathBlockPreview extends Component {
  @service siteSettings;

  // the renderers replace the element's content, so it is built outside of
  // Glimmer's reach and rebuilt from scratch for each source
  renderMath = modifier((element, [source]) => {
    const math = document.createElement("div");
    math.classList.add("math");
    math.textContent = source;
    element.replaceChildren(math);

    renderMathInElement(element, buildDiscourseMathOptions(this.siteSettings), {
      force: true,
    });
  });

  <template>
    <div class="math-block-preview" {{this.renderMath @source}}></div>
  </template>
}
