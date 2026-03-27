import Component from "@glimmer/component";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import CategoryReadOnlyBanner from "discourse/components/category-read-only-banner";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";

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
  @service siteSettings;

  <template>
    <DiscourseBanner />
    {{#if @model.category}}
      <CategoryReadOnlyBanner
        @category={{@model.category}}
        @readOnly={{@createTopicDisabled}}
      />
    {{/if}}

    <PluginOutlet
      @name="discovery-list-controls-above"
      @connectorTagName="div"
      @outletArgs={{lazyHash
        category=@model.category
        tag=@model.tag
        toggleTagInfo=@toggleTagInfo
      }}
    />

    <div class="list-controls">
      <PluginOutlet
        @name="discovery-navigation-bar-above"
        @connectorTagName="div"
        @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
      />
      <div class="container">
        {{yield to="navigation"}}
      </div>
    </div>

    <ConditionalWrap
      @when={{this.siteSettings.discovery_layout_with_sidebar_block}}
      @class="discovery-layout discovery-layout__content"
    >
      <PluginOutlet
        @name="discovery-above"
        @connectorTagName="div"
        @outletArgs={{lazyHash
          category=@model.category
          tag=@model.tag
          model=@model
        }}
      />

      <ConditionalWrap
        @when={{this.siteSettings.discovery_layout_with_sidebar_block}}
        @class="discovery-layout__list"
      >
        <div class={{concatClass "container list-container" @listClass}}>
          <div class="row full-width">
            <div id="header-list-area">
              {{yield to="header"}}
              <PluginOutlet
                @name="header-list-container-bottom"
                @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
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
                @name="discovery-list-area"
                @outletArgs={{lazyHash
                  category=@model.category
                  tag=@model.tag
                  model=@model
                }}
                @defaultGlimmer={{true}}
              >
                <PluginOutlet
                  @name="discovery-list-container-top"
                  @connectorTagName="span"
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

      {{#if this.siteSettings.discovery_layout_with_sidebar_block}}
        <div class="discovery-layout__sidebar">
          <BlockOutlet
            @name="sidebar-discovery"
            @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
          />
        </div>
      {{/if}}

      <PluginOutlet
        @name="discovery-below"
        @connectorTagName="div"
        @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
      />
    </ConditionalWrap>
  </template>
}
