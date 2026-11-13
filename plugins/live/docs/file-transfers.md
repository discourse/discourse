# User-to-user file transfers

File transfers are optional and **disabled by default**. Enable
`live_file_transfer_enabled` together with `live_enabled` to let participants in
mesh (peer-to-peer) rooms exchange files up to **100 MiB (104,857,600 bytes)**.
LiveKit rooms do not support this feature. The data channel is negotiated even
when transfers are disabled; changing the setting does not require rejoining.
Eligibility is checked again when sending or accepting a file.

## Sending and receiving

1. Join a mesh room and wait for the connection to the recipient to open.
2. Open the participant menu from the sidebar or a video tile. Both use the same
   menu component. Choose **Send file…**, then select one file from your device.
   The action is hidden for yourself, unavailable peers, rooms you have not
   joined, non-mesh rooms, and when the setting is disabled.
3. The recipient sees the sender, room, filename, and size in the **File
   transfers** panel. They must explicitly **Accept** or **Reject** the offer.
4. The panel shows transfer status/progress and cancellation controls. It remains
   available when the participant menu closes, when the call widget is hidden,
   and while browsing other Discourse pages. The panel sits below the header,
   away from the bottom call controls and beneath dropdown menus. Use its
   **Collapse**/**Expand** button to uncover page controls; the compact header
   keeps a count of pending incoming offers. A new incoming offer expands the
   panel again, but progress updates do not. A scrollable, height-limited panel
   keeps multiple offers accessible.
5. After receiving completes, choose **Save file** to download an attachment.
   Receiving never automatically saves, previews, opens, or executes content.
   Filenames are sanitized and the download uses `application/octet-stream`.
   Temporary download object URLs are revoked by Discourse’s download helper.
   Sender completion waits for the receiver’s completion acknowledgement.
6. **Dismiss** removes finished transfers and releases retained content. Completed
   incoming blobs stay in browser memory until dismissal or session teardown;
   saving does not automatically dismiss them, so a failed save can be retried.

## Privacy and limitations

- File contents travel through an encrypted WebRTC data channel between browsers.
  A TURN server may relay encrypted traffic when a direct connection is not
  possible. Peer-to-peer does not necessarily mean a direct network path.
- Files are **not uploaded to Discourse**, made into Discourse uploads, stored as
  posts/chat attachments, or scanned for viruses. Only accept files from people
  you trust. Downloading safely does not make the contents safe to open later.
- This is a live session feature, not durable/offline delivery. Both people must
  stay connected; leaving or disconnecting interrupts unfinished transfers.
  Reloading or closing the browser loses in-memory transfer history/content.
- The limit is per file; transport also bounds retained receive memory and queued
  offers. Cancel or dismiss old transfers before retrying when capacity is full.
- The UI consumes the live WebRTC service’s reactive `fileTransfers` array and
  consent/cancel/dismiss methods. It never handles data-channel protocol traffic.
