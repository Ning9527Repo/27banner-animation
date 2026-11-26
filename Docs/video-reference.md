# Video reference and verification scope

The target is the user's supplied notification demonstration, not an assumed
publicly documented iOS animation API. Its platform/version and Siri dependency
cannot be authenticated from a reposted recording alone.

Reference file SHA-256:
`cfd37d8382e5e6189dc78cfc25997adb30aae925cedee6fdc60495deb7fb89b3`

Container: 946 x 720, 30 frames/s, 20.7 seconds. The video and extracted frames
are private working evidence and are not distributed in this repository.

## Required behavior

- A compact notification appears near the leading status-bar time area.
- It expands and moves into the ordinary notification banner position.
- A normal dismissal collapses the banner toward that leading area.
- A thin rounded indicator remains below the time after dismissal. It can
  coexist with a later banner, so it cannot simply be a permanently frozen
  notification layer or a retained snapshot of the previous message.
- Disable / Reduce Motion must remove all owned animations and indicators.
- Preserve system-owned notification content, tap routing, gestures and long-look.
- No arbitrary elasticity slider. Do not replace reference motion with an
  invented spring or claim that a third-party reconstruction is Apple's source.

## Evidence limits

The last unambiguous screen frames at 19.0 and 19.5 seconds show the indicator
with no banner. This proves persistence in the recording, not infinite duration,
a tap/reopen action, unread-count semantics, or dismissal rules outside the clip.
Those unspecified interactions must not be invented as demonstrated behavior.

## Validation levels

C numerical tests and Objective-C syntax checks establish math/type properties.
An iOS build and code-signature check establish package integrity. Neither is a
visual match or SpringBoard stability test. A same-device, frame-aligned recording
is required before describing an implementation as a 1:1 match.

## Geometry and timing observations

Thresholded green-icon support in the first entrance (not an exact translucent
banner contour) is reproducibly measured in private working evidence:

| Video time | Icon support / banner observation |
| --- | --- |
| 0.50 s | Small notification near x=82..182, y=126..143 |
| 0.80 s | Banner approximately x=124..657, y=169..318 |
| 1.00 s | Banner approximately x=62..914, y=139..295; not yet its final width |
| 19.50 s | No banner; a horizontal line remains near x=86..203, y=121..126 |

These rounded pixel ranges are visual support in a compressed recording, not
native UIKit points, a certified alpha value, or an excuse to hard-code a screen
coordinate. The status text/focus symbol, wallpaper scale, device and screen
capture can differ. The implementation obtains the current native time-item
geometry and converts it to the notification card's coordinate space.

The four recovered scale/position channels and 0.86-second entrance envelope
remain in `NB27Motion.h`. `NB27ReferenceMotion.h` changes the compact origin while
preserving those channels and anchor-point compensation. This is a reconstruction
choice compatible with the visible path, not a claim that the video uniquely
identifies Apple's internal curve. The exit is limited by the native dismissal
lifetime; the tweak never stalls UIKit's completion callback to extend a clip.

## Integration behavior

Only the normal native disappearance lifecycle can commit the retained line.
A CA animation reaching its last frame is insufficient: a cancellation or system
handoff must not leave a newly created indicator. Old generation tickets cannot
clear or revive a newer retained state. The indicator window never becomes key,
never consumes touches and never copies notification content or icons.

When a trustworthy native time anchor, lock state or supported geometry is not
available, the owned indicator stays hidden. This intentional fallback is not
reported as a successful reference match. Native material and notification data
remain system owned; no new shader, material replacement or notification icon
hook is introduced by this version.
