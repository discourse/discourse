// Extract the ICE username fragment from an SDP. A new value vs the prior
// remote description signals the peer restarted its ICE session (e.g. left
// and rejoined), which needs a fresh peer rather than a renegotiation.
export function iceUfrag(sdp) {
  const match = sdp?.match(/^a=ice-ufrag:(\S+)/m);
  return match ? match[1] : null;
}
