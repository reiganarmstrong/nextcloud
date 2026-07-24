# Security policy

Do not open a public issue containing credentials, `.env`, Nextcloud
`config.php`, logs with tokens, tailnet details, or user data. Rotate any secret
that reaches Git history; adding it to `.gitignore` afterward is not enough.

This configuration intentionally publishes only the Nextcloud HTTP port. It is
designed for an encrypted Tailscale network and must not be exposed directly to
the public internet.
