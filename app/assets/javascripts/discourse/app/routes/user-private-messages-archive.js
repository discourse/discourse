import createPMRoute, {
  ARCHIVE_FILTER,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "all",
  "private-messages-all-archive",
  ARCHIVE_FILTER
);
