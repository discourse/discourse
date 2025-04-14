<StyleguideExample @title="<DTooltip />">
  <Styleguide::Component @tag="tooltip component">
    <:sample>
      <DTooltip
        @label={{this.label}}
        @offset={{this.offset}}
        @arrow={{this.arrow}}
        @maxWidth={{this.maxWidth}}
        @identifier={{this.identifier}}
        @interactive={{this.interactive}}
        @triggers={{this.triggers}}
        @untriggers={{this.untriggers}}
        @content={{this.content}}
        @inline={{this.inline}}
      />
    </:sample>
  </Styleguide::Component>

  <Styleguide::Component @tag="tooltip component">
    <:sample>
      <DTooltip
        @offset={{this.offset}}
        @arrow={{this.arrow}}
        @maxWidth={{this.maxWidth}}
        @identifier={{this.identifier}}
        @interactive={{this.interactive}}
        @triggers={{this.triggers}}
        @untriggers={{this.untriggers}}
        @content={{this.content}}
        @inline={{this.inline}}
      >
        <:trigger>
          {{this.label}}
        </:trigger>
        <:content>
          {{this.content}}
        </:content>
      </DTooltip>
    </:sample>
  </Styleguide::Component>

  <Styleguide::Component @tag="tooltip service">
    <:sample>
      <span id="tooltip-instance">{{this.label}}</span>
    </:sample>
    <:actions>
      <DButton @action={{this.registerTooltip}}>Register</DButton>
    </:actions>
  </Styleguide::Component>

  <Styleguide::Component @tag="tooltip service">
    <:sample>
      <span id="tooltip-instance-with-component">{{this.label}}</span>
    </:sample>
    <:actions>
      <DButton @action={{this.registerTooltipWithComponent}}>Register</DButton>
    </:actions>
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Example label">
      <Input @value={{this.label}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@content]">
      <Input @value={{this.content}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@identifier]">
      <Input @value={{this.identifier}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@offset]">
      <Input @value={{this.offset}} @type="number" />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@triggers]">
      <Input @value={{this.triggers}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@untriggers]">
      <Input @value={{this.untriggers}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@maxWidth]">
      <Input @value={{this.maxWidth}} @type="number" />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@interactive]">
      <DToggleSwitch
        @state={{this.interactive}}
        {{on "click" this.toggleInteractive}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@arrow]">
      <DToggleSwitch @state={{this.arrow}} {{on "click" this.toggleArrow}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@inline]">
      <DToggleSwitch @state={{this.inline}} {{on "click" this.toggleInline}} />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>