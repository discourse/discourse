import NavigationBar from "discourse/components/navigation-bar";

export default <template>
  <NavigationBar @filterMode="latest" @navItems={{@navItems}} />
</template>
