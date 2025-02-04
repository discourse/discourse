export function adminRouteValid(router, adminRoute) {
  try {
    if (adminRoute.use_new_show_route) {
      router.urlFor(adminRoute.full_location, adminRoute.location);
    } else {
      router.urlFor(adminRoute.full_location);
    }
    return true;
  } catch {
    return false;
  }
}
