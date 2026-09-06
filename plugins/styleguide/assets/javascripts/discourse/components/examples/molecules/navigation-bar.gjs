import NavigationBar from "discourse/components/navigation-bar";

export default <template>
  <NavigationBar @navItems={{@navItems}} @filterMode="latest" />
</template>
