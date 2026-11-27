# Security policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue: open the
repository's **Security** tab and choose **Report a vulnerability**
(<https://github.com/ebmohsenn/vps-monitor-ios/security/advisories/new>).

Include what you found, the steps that reproduce it, and the impact you expect.
You will get an acknowledgement within a few days.

Only the latest release receives security fixes.

## Known limits of the design

These are documented trade-offs of a single-user tool, not vulnerabilities:

- The HMAC secret is compiled into the app bundle. Anyone holding the app
  binary can read it, so treat it as a lightweight access key and put the
  endpoint behind a VPN, mTLS or an IP allow-list if you need more.
- A signed request stays valid for 5 minutes and carries no nonce, so a
  captured request can be replayed in that window to read the same data.
- The reference server answers anyone when `VPS_HMAC_SECRET` is not set.
