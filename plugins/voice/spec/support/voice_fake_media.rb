# frozen_string_literal: true

require "json"

module VoiceFakeMedia
  DEFAULT_VIDEO_FEEDS = [
    { label: "Voice fake camera A", width: 640, height: 360, color: "#2563eb", accent: "#f97316" },
    { label: "Voice fake camera B", width: 640, height: 360, color: "#16a34a", accent: "#7c3aed" },
    { label: "Voice fake camera C", width: 640, height: 360, color: "#dc2626", accent: "#0891b2" },
  ].freeze

  def install_voice_fake_media(video_feeds: DEFAULT_VIDEO_FEEDS)
    feeds_json = JSON.generate(video_feeds)

    page.driver.with_playwright_page do |playwright_page|
      playwright_page.add_init_script(script: <<~JS)
        (() => {
          if (window.__voiceFakeMediaInstalled) {
            return;
          }

          window.__voiceFakeMediaInstalled = true;
          window.__voiceFakeMediaStreams = [];
          window.__voiceFakeMediaVideoFeeds = #{feeds_json};
          window.__voiceFakeMediaVideoFeedIndex = 0;

          const mediaDevices = navigator.mediaDevices || {};
          Object.defineProperty(navigator, "mediaDevices", {
            configurable: true,
            value: mediaDevices,
          });

          function nextVideoFeed() {
            const feeds = window.__voiceFakeMediaVideoFeeds;
            const index = window.__voiceFakeMediaVideoFeedIndex % feeds.length;
            window.__voiceFakeMediaVideoFeedIndex += 1;
            return feeds[index];
          }

          function cleanupWhenTrackStops(track, cleanup) {
            let cleaned = false;
            const runCleanup = () => {
              if (cleaned) {
                return;
              }
              cleaned = true;
              cleanup();
            };
            const originalStop = track.stop.bind(track);
            track.stop = () => {
              runCleanup();
              originalStop();
            };
            track.addEventListener("ended", runCleanup, { once: true });
          }

          function createVideoStream(feed) {
            const { label, width, height, color, accent } = feed;
            const canvas = document.createElement("canvas");
            canvas.width = width;
            canvas.height = height;
            const context = canvas.getContext("2d");
            let frame = 0;

            const drawFrame = () => {
              frame += 1;
              const x = (frame * 17) % width;
              const y = height / 2 - 40;

              context.fillStyle = color;
              context.fillRect(0, 0, width, height);
              context.fillStyle = "rgba(255, 255, 255, 0.18)";
              context.fillRect(0, height - 96, width, 96);
              context.fillStyle = accent || "rgba(0, 0, 0, 0.35)";
              context.fillRect(x, y, 120, 80);
              context.fillStyle = "#fff";
              context.font = "32px sans-serif";
              context.fillText(label, 24, 48);
              context.font = "20px sans-serif";
              context.fillText(`frame ${frame}`, 24, height - 38);
            };

            drawFrame();
            const timer = window.setInterval(drawFrame, 100);
            const stream = canvas.captureStream(10);
            stream.__voiceFakeMediaLabel = label;
            stream.getTracks().forEach((track) => {
              track.__voiceFakeMediaLabel = label;
              cleanupWhenTrackStops(track, () => window.clearInterval(timer));
            });
            window.__voiceFakeMediaStreams.push(stream);
            return stream;
          }

          function createAudioStream() {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            const audioContext = new AudioContext();
            const oscillator = audioContext.createOscillator();
            const gain = audioContext.createGain();
            const destination = audioContext.createMediaStreamDestination();

            oscillator.frequency.value = 220;
            gain.gain.value = 0.0001;
            oscillator.connect(gain);
            gain.connect(destination);
            oscillator.start();
            destination.stream.getTracks().forEach((track) => {
              cleanupWhenTrackStops(track, () => {
                oscillator.stop();
                audioContext.close();
              });
            });
            window.__voiceFakeMediaStreams.push(destination.stream);
            return destination.stream;
          }

          function addTracks(target, source) {
            source.getTracks().forEach((track) => target.addTrack(track));
          }

          mediaDevices.getUserMedia = async (constraints = {}) => {
            const stream = new MediaStream();

            if (constraints.audio) {
              addTracks(stream, createAudioStream());
            }

            if (constraints.video) {
              const videoStream = createVideoStream(nextVideoFeed());
              stream.__voiceFakeMediaLabel = videoStream.__voiceFakeMediaLabel;
              addTracks(stream, videoStream);
            }

            return stream;
          };

          mediaDevices.getDisplayMedia = async () => {
            return createVideoStream({
              label: "Voice fake screen",
              width: 1024,
              height: 576,
              color: "#16a34a",
              accent: "#111827",
            });
          };

          mediaDevices.enumerateDevices = async () => {
            return window.__voiceFakeMediaVideoFeeds.map((feed, index) => ({
              deviceId: `voice-fake-camera-${index}`,
              groupId: `voice-fake-group-${index}`,
              kind: "videoinput",
              label: feed.label,
              toJSON() {
                return this;
              },
            }));
          };
        })();
      JS
    end
  end

  def voice_media_track_count(selector, kind: :video, timeout: 5)
    page.evaluate_async_script(<<~JS, selector, kind.to_s, timeout * 1000)
      const [selector, kind, timeoutMs, done] = arguments;
      const startedAt = performance.now();
      const trackCount = () => {
        const stream = document.querySelector(selector)?.srcObject;
        if (!stream) {
          return 0;
        }
        return kind === "audio" ? stream.getAudioTracks().length : stream.getVideoTracks().length;
      };
      const waitForTracks = () => {
        const count = trackCount();
        if (count > 0 || performance.now() - startedAt > timeoutMs) {
          done(count);
        } else {
          requestAnimationFrame(waitForTracks);
        }
      };
      waitForTracks();
    JS
  end

  def voice_media_track_live?(selector, kind: :video, timeout: 5)
    page.evaluate_async_script(<<~JS, selector, kind.to_s, timeout * 1000)
      const [selector, kind, timeoutMs, done] = arguments;
      const startedAt = performance.now();
      const trackLive = () => {
        const stream = document.querySelector(selector)?.srcObject;
        if (!stream?.active) {
          return false;
        }

        const tracks =
          kind === "audio" ? stream.getAudioTracks() : stream.getVideoTracks();
        return tracks.some((track) => track.readyState === "live" && track.enabled);
      };
      const waitForLiveTrack = () => {
        if (trackLive()) {
          done(true);
        } else if (performance.now() - startedAt > timeoutMs) {
          done(false);
        } else {
          requestAnimationFrame(waitForLiveTrack);
        }
      };
      waitForLiveTrack();
    JS
  end
end

RSpec.configure { |config| config.include VoiceFakeMedia, type: :system }
