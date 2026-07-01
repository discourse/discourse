import outletAnimationModifier from "./outlet-animation-modifier";

const Outlet = <template>
  <div
    {{outletAnimationModifier @sheet @travelAnimation @stackingAnimation}}
    ...attributes
  >
    {{yield}}
  </div>
</template>;

export default Outlet;
