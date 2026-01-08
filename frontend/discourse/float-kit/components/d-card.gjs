import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import DSheet from "./d-sheet";

class DCard extends Component {
  @action
  backdropTravelAnimation(progress) {
    return Math.min(0.4 * progress, 0.4);
  }

  get componentId() {
    return this.args.componentId ?? guidFor(this);
  }

  <template>
    <DSheet.Root @componentId={{this.componentId}} as |sheet|>
      {{yield
        (hash
          Trigger=(component
            DSheet.Trigger forComponent=this.componentId sheet=sheet
          )
        )
        to="root"
      }}

      <DSheet.Portal @sheet={{sheet}}>
        <DSheet.View
          class="d-card"
          @sheet={{sheet}}
          @contentPlacement="center"
          @tracks="top"
          @enteringAnimationSettings={{hash
            easing="spring"
            stiffness=260
            damping=20
            mass=1
          }}
        >
          <DSheet.Backdrop
            @travelAnimation={{this.backdropTravelAnimation}}
            @themeColorDimming="auto"
            @sheet={{sheet}}
          />
          <DSheet.Content
            @travelAnimation={{hash scale=(array 0.8 1)}}
            class="d-card-content"
            @sheet={{sheet}}
          >
            {{!-- <DSheet.Handle @sheet={{sheet}} /> --}}

            <DSheet.Scroll.Root as |scroll|>
              <scroll.View>
                <scroll.Content>
                  {{#if (has-block "content")}}
                    {{yield
                      (hash Trigger=(component DSheet.Trigger sheet=sheet))
                      to="content"
                    }}
                  {{else}}
                    {{yield
                      (hash Trigger=(component DSheet.Trigger sheet=sheet))
                    }}
                  {{/if}}
                </scroll.Content>
              </scroll.View>
            </DSheet.Scroll.Root>
          </DSheet.Content>
        </DSheet.View>
      </DSheet.Portal>
    </DSheet.Root>
  </template>
}

export default DCard;
