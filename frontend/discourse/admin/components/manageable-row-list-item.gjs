import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ManageableRowListItem extends Component {
  @service site;

  @tracked dragCssClass;
  dragCount = 0;

  isAboveElement(event) {
    const domRect = event.currentTarget.getBoundingClientRect();
    return event.offsetY < domRect.height / 2;
  }

  @action
  dragStart(event) {
    event.dataTransfer.effectAllowed = "move";
    this.args.onDragStart(this.args.row.key);
    this.dragCssClass = "dragging";
  }

  @action
  dragOver(event) {
    if (!this.args.row.enabled) {
      return;
    }
    event.preventDefault();
    if (this.dragCssClass === "dragging") {
      return;
    }
    this.dragCssClass = this.isAboveElement(event)
      ? "drag-above"
      : "drag-below";
  }

  @action
  dragEnter() {
    this.dragCount++;
  }

  @action
  dragLeave() {
    this.dragCount--;
    if (
      this.dragCount === 0 &&
      (this.dragCssClass === "drag-above" || this.dragCssClass === "drag-below")
    ) {
      this.dragCssClass = null;
    }
  }

  @action
  drop(event) {
    if (!this.args.row.enabled) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    this.dragCount = 0;
    const dropAbove = this.isAboveElement(event);
    this.dragCssClass = null;
    this.args.onDrop(this.args.row.key, dropAbove);
  }

  @action
  dragEnd() {
    this.dragCount = 0;
    this.dragCssClass = null;
    this.args.onDragEnd();
  }

  <template>
    <li
      class={{dConcatClass
        (concat @blockName "__row")
        (if @row.enabled "--enabled")
        this.dragCssClass
      }}
      data-identifier={{@row.key}}
      draggable={{and @row.enabled @reorderable}}
      {{on "dragstart" this.dragStart}}
      {{on "dragover" this.dragOver}}
      {{on "dragenter" this.dragEnter}}
      {{on "dragleave" this.dragLeave}}
      {{on "drop" this.drop}}
      {{on "dragend" this.dragEnd}}
    >

      {{#unless this.site.mobileView}}
        <span class={{concat @blockName "__grip"}}>
          {{dIcon "grip-vertical"}}
        </span>
      {{/unless}}

      {{#if this.site.mobileView}}
        <div class={{concat @blockName "__order-mobile"}}>
          <DButton
            @icon="arrow-up"
            @action={{fn @onMoveUp @row}}
            @disabled={{eq @index 0}}
            @translatedAriaLabel={{i18n
              (concat @ariaLabelPrefix ".move_up")
              title=@row.title
            }}
            class={{concat @blockName "__arrow btn-transparent"}}
          />
          <DButton
            @icon="arrow-down"
            @action={{fn @onMoveDown @row}}
            @disabled={{eq @index @lastEnabledIndex}}
            @translatedAriaLabel={{i18n
              (concat @ariaLabelPrefix ".move_down")
              title=@row.title
            }}
            class={{concat @blockName "__arrow btn-transparent"}}
          />
        </div>
      {{/if}}

      <div class={{concat @blockName "__row-text"}}>
        <div class={{concat @blockName "__row-heading"}}>
          <span class={{concat @blockName "__title"}}>{{@row.title}}</span>
          {{#if @row.label}}
            <span class="db-report__label">
              {{@row.label}}
            </span>
          {{/if}}
        </div>
        {{#if @row.description}}
          <p
            class={{concat @blockName "__description"}}
          >{{@row.description}}</p>
        {{/if}}
      </div>

      <DToggleSwitch
        @state={{@row.enabled}}
        disabled={{@toggleDisabled}}
        aria-label={{i18n
          (if
            @row.enabled
            (concat @ariaLabelPrefix ".disable")
            (concat @ariaLabelPrefix ".enable")
          )
          title=@row.title
        }}
        {{on "click" (fn @onToggle @row)}}
      />
    </li>
  </template>
}
