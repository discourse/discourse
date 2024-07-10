{{~#if @tagName~}}
  {{!
    Older outlets have a wrapper tagName. RFC0389 proposes an interface for dynamic tag names, which we may want to use in future.
    But for now, this classic component wrapper takes care of the tagName.
  }}
  <this.wrapperComponent @tagName={{@tagName}}>
    {{~#each (this.getConnectors) as |c|~}}
      {{~#if c.componentClass~}}
        <c.componentClass @outletArgs={{this.outletArgsWithDeprecations}} />
      {{~else if @defaultGlimmer~}}
        <c.templateOnly @outletArgs={{this.outletArgsWithDeprecations}} />
      {{~else~}}
        <PluginConnector
          @connector={{c}}
          @args={{this.outletArgs}}
          @deprecatedArgs={{@deprecatedArgs}}
          @outletArgs={{this.outletArgsWithDeprecations}}
          @tagName={{or @connectorTagName ""}}
          @layout={{c.template}}
          class={{c.classicClassNames}}
        />
      {{~/if~}}
    {{~/each~}}
  </this.wrapperComponent>
{{~else if (this.connectorsExist hasBlock=(has-block))~}}
  {{~! The modern path: no wrapper element = no classic component ~}}

  {{~#if (has-block)~}}
    <PluginOutlet
      @name={{concat @name "__before"}}
      @outletArgs={{this.outletArgsWithDeprecations}}
    />
  {{~/if~}}

  {{~#each (this.getConnectors hasBlock=(has-block)) as |c|~}}
    {{~#if c.componentClass~}}
      <c.componentClass
        @outletArgs={{this.outletArgsWithDeprecations}}
      >{{yield}}</c.componentClass>
    {{~else if @defaultGlimmer~}}
      <c.templateOnly
        @outletArgs={{this.outletArgsWithDeprecations}}
      >{{yield}}</c.templateOnly>
    {{~else~}}
      <PluginConnector
        @connector={{c}}
        @args={{this.outletArgs}}
        @deprecatedArgs={{@deprecatedArgs}}
        @outletArgs={{this.outletArgsWithDeprecations}}
        @tagName={{or @connectorTagName ""}}
        @layout={{c.template}}
        class={{c.classicClassNames}}
      >{{yield}}</PluginConnector>
    {{~/if~}}
  {{~else~}}
    {{yield}}
  {{~/each~}}

  {{~#if (has-block)~}}
    <PluginOutlet
      @name={{concat @name "__after"}}
      @outletArgs={{this.outletArgsWithDeprecations}}
    />
  {{~/if~}}
{{~else~}}
  {{yield}}
{{~/if~}}