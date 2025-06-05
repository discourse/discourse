import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import HighlightedCode from "admin/components/highlighted-code";

export default class FullscreenCode extends Component {
  <template>
    <DModal class="fullscreen-code-modal -max">
      <:body>
        <HighlightedCode
          @code={{@model.code}}
          @highlightedLines={{@model.highlightedLines}}
          @numbers={{@model.numbers}}
          @path={{@model.path}}
          @lang={{@model.lang}}
          @showCopy={{true}}
          @close={{@closeModal}}
        />
      </:body>
    </DModal>
  </template>
}
