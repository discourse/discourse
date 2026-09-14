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
        "manageable-row-list__row"
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
        <span class="manageable-row-list__grip">
          {{dIcon "grip-vertical"}}
        </span>
      {{/unless}}

      {{#if this.site.mobileView}}
        <div class="manageable-row-list__order-mobile">
          <DButton
            class="manageable-row-list__arrow btn-transparent"
            @action={{fn @onMoveUp @row}}
            @disabled={{eq @index 0}}
            @icon="arrow-up"
            @translatedAriaLabel={{i18n
              (concat @ariaLabelPrefix ".move_up")
              title=@row.title
            }}
          />
          <DButton
            class="manageable-row-list__arrow btn-transparent"
            @action={{fn @onMoveDown @row}}
            @disabled={{eq @index @lastEnabledIndex}}
            @icon="arrow-down"
            @translatedAriaLabel={{i18n
              (concat @ariaLabelPrefix ".move_down")
              title=@row.title
            }}
          />
        </div>
      {{/if}}

      <div class="manageable-row-list__row-text">
        <div class="manageable-row-list__row-heading">
          <span class="manageable-row-list__title">{{@row.title}}</span>
          {{#if @row.label}}
            <span class="db-report__label">
              {{@row.label}}
            </span>
          {{/if}}
        </div>
        {{#if @row.description}}
          <p class="manageable-row-list__description">{{@row.description}}</p>
        {{/if}}
      </div>

      <DToggleSwitch
        aria-label={{i18n
          (if
            @row.enabled
            (concat @ariaLabelPrefix ".disable")
            (concat @ariaLabelPrefix ".enable")
          )
          title=@row.title
        }}
        disabled={{@toggleDisabled}}
        @state={{@row.enabled}}
        {{on "click" (fn @onToggle @row)}}
      />
    </li>
  </template>
}
