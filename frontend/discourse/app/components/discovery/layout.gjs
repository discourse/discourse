import Component from "@glimmer/component";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import CategoryReadOnlyBanner from "discourse/components/category-read-only-banner";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/* Renders its content inside a <div> with the given class when @when is true,
   or renders the content directly when false. */
const ConditionalWrap = <template>
  {{#if @when}}
    <div class={{@class}}>{{yield}}</div>
  {{else}}
    {{yield}}
  {{/if}}
</template>;

export default class Layout extends Component {
  @service blocks;

  get hasSidebarLayout() {
    return this.blocks.hasLayout("sidebar-discovery");
  }

  <template>
    <ConditionalWrap @class="discovery-layout" @when={{this.hasSidebarLayout}}>
      <DiscourseBanner />

      <ConditionalWrap
        @class="discovery-layout__category-header"
        @when={{this.hasSidebarLayout}}
      >
        {{#if @model.category}}
          <CategoryReadOnlyBanner
            @category={{@model.category}}
            @readOnly={{@createTopicDisabled}}
          />
        {{/if}}
      </ConditionalWrap>

      {{#if (has-block "aboveNavigation")}}
        <ConditionalWrap
          @class="discovery-layout__above-navigation"
          @when={{this.hasSidebarLayout}}
        >
          {{yield to="aboveNavigation"}}
        </ConditionalWrap>
      {{/if}}

      <ConditionalWrap
        @class="discovery-layout__navigation"
        @when={{this.hasSidebarLayout}}
      >
        <PluginOutlet
          @connectorTagName="div"
          @name="discovery-list-controls-above"
          @outletArgs={{lazyHash
            category=@model.category
            tag=@model.tag
            toggleTagInfo=@toggleTagInfo
          }}
        />
        <div class="list-controls">
          <PluginOutlet
            @connectorTagName="div"
            @name="discovery-navigation-bar-above"
            @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
          />
          <div class="container">
            {{yield to="navigation"}}
          </div>
        </div>
      </ConditionalWrap>

      <ConditionalWrap
        @class="discovery-layout__content"
        @when={{this.hasSidebarLayout}}
      >
        <PluginOutlet
          @connectorTagName="div"
          @name="discovery-above"
          @outletArgs={{lazyHash
            category=@model.category
            tag=@model.tag
            model=@model
          }}
        />

        <ConditionalWrap
          @class="discovery-layout__list"
          @when={{this.hasSidebarLayout}}
        >
          <div class={{dConcatClass "container list-container" @listClass}}>
            <div class="row full-width">
              <div id="header-list-area">
                {{yield to="header"}}
                <PluginOutlet
                  @name="header-list-container-bottom"
                  @outletArgs={{lazyHash
                    category=@model.category
                    tag=@model.tag
                  }}
                />
              </div>
            </div>
            <div class="row full-width">
              <PluginOutlet
                @name="before-list-area"
                @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
              />
              <div id="list-area">
                <PluginOutlet
                  @defaultGlimmer={{true}}
                  @name="discovery-list-area"
                  @outletArgs={{lazyHash
                    category=@model.category
                    tag=@model.tag
                    model=@model
                  }}
                >
                  <PluginOutlet
                    @connectorTagName="span"
                    @name="discovery-list-container-top"
                    @outletArgs={{lazyHash
                      category=@model.category
                      tag=@model.tag
                    }}
                  />
                  {{yield to="list"}}
                </PluginOutlet>
              </div>
            </div>
          </div>
        </ConditionalWrap>

        {{#if this.hasSidebarLayout}}
          <div class="discovery-layout__sidebar">
            <BlockOutlet
              @name="sidebar-discovery"
              @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
            />
          </div>
        {{/if}}

        <PluginOutlet
          @connectorTagName="div"
          @name="discovery-below"
          @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
        />
      </ConditionalWrap>
    </ConditionalWrap>
  </template>
}
