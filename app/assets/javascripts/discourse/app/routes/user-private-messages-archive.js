import createPMRoute, {
  ARCHIVE_FILTER,
} from "discourse/routes/build-private-messages-route";

export default createPMRoute(
  "user",
  "private-messages-archive",
  ARCHIVE_FILTER
);
