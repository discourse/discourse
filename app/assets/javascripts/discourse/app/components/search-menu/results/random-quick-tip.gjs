<li class="search-random-quick-tip">
  <button
    class={{concat-class
      "tip-label"
      (if this.randomTip.clickable "tip-clickable")
    }}
    {{on "click" this.tipSelected}}
    aria-describedby="tip-description"
  >
    {{this.randomTip.label}}
  </button>

  <span id="tip-description">
    {{this.randomTip.description}}
  </span>
</li>